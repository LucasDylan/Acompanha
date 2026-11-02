"""
Booking lifecycle rules, shared by the API views, the Stripe webhook and
account deletion.
"""
from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from payments.connect import host_can_receive, payouts_required
from profiles.models import Slot
from safety.models import is_blocked

from .models import Booking


class BookingError(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.message = message
        self.status = status


def booking_amount(host, slot):
    hours = Decimal((slot.end_at - slot.start_at).total_seconds()) / Decimal(3600)
    return ((host.price_per_hour or Decimal('0')) * hours).quantize(Decimal('0.01'))


def expire_unpaid_bookings():
    """Release slots held by bookings whose payment window ran out."""
    from payments.models import Payment

    cutoff = timezone.now() - timedelta(minutes=settings.BOOKING_PAYMENT_WINDOW_MINUTES)
    stale = (
        Booking.objects
        .filter(status=Booking.STATUS_PENDING, created_at__lt=cutoff)
        .exclude(payment__status=Payment.STATUS_CAPTURED)
        .select_related('slot')
    )
    for booking in stale:
        booking.status = Booking.STATUS_CANCELLED
        booking.cancelled_at = timezone.now()
        booking.save(update_fields=['status', 'cancelled_at', 'updated_at'])
        if booking.slot.status == Slot.STATUS_BOOKED:
            booking.slot.status = Slot.STATUS_AVAILABLE
            booking.slot.save(update_fields=['status'])


def complete_finished_bookings():
    """Confirmed meetings whose time is over become completed (and reviewable)."""
    Booking.objects.filter(
        status=Booking.STATUS_CONFIRMED, slot__end_at__lt=timezone.now(),
    ).update(status=Booking.STATUS_COMPLETED, updated_at=timezone.now())


def create_booking(client, slot_id, host_id):
    if not slot_id or not host_id:
        raise BookingError('Escolha um horário.')
    expire_unpaid_bookings()

    with transaction.atomic():
        # Lock the slot row so two people tapping "pay" at once can't both get it.
        slot = (
            Slot.objects.select_for_update()
            .select_related('host', 'host__user')
            .filter(pk=slot_id, host_id=host_id)
            .first()
        )
        if slot is None:
            raise BookingError('Horário não encontrado.', status=404)
        host = slot.host
        if host.user_id == client.id:
            raise BookingError('Você não pode reservar um horário seu.')
        if not host.is_active or not host.user.is_active:
            raise BookingError('Este anfitrião não está aceitando reservas no momento.')
        if is_blocked(client, host.user):
            raise BookingError('Não é possível reservar com este anfitrião.', status=403)
        if payouts_required() and not host_can_receive(host):
            raise BookingError('Este anfitrião ainda não pode receber pagamentos pelo app.', status=409)
        if slot.start_at <= timezone.now():
            raise BookingError('Este horário já passou.')
        if slot.status != Slot.STATUS_AVAILABLE:
            raise BookingError('Este horário não está mais disponível.')

        amount = booking_amount(host, slot)
        needs_payment = amount > 0 and not settings.ALLOW_UNPAID_BOOKINGS
        booking = Booking.objects.create(
            client=client,
            host=host,
            slot=slot,
            amount=amount,
            currency=host.currency,
            status=Booking.STATUS_PENDING if needs_payment else Booking.STATUS_CONFIRMED,
        )
        slot.status = Slot.STATUS_BOOKED
        slot.save(update_fields=['status'])
    return booking


def refund_due(booking, by_host):
    """Whether cancelling now gives the client their money back."""
    if by_host:
        return True
    notice = booking.slot.start_at - timezone.now()
    return notice >= timedelta(hours=settings.FREE_CANCELLATION_HOURS)


def cancel_booking(booking_id, user):
    from payments.services import PaymentError, captured_payment, refund_payment

    with transaction.atomic():
        booking = (
            Booking.objects.select_for_update()
            .select_related('slot', 'host')
            .filter(pk=booking_id)
            .first()
        )
        if booking is None:
            raise BookingError('Reserva não encontrada.', status=404)
        by_client = booking.client_id == user.id
        by_host = booking.host.user_id == user.id
        if not (by_client or by_host):
            raise BookingError('Reserva não encontrada.', status=404)
        if booking.status not in (Booking.STATUS_PENDING, Booking.STATUS_CONFIRMED):
            raise BookingError('Esta reserva não pode mais ser cancelada.')
        if booking.slot.start_at <= timezone.now():
            raise BookingError('O encontro já começou e não pode mais ser cancelado.')

        payment = captured_payment(booking)
        if payment and refund_due(booking, by_host):
            try:
                refund_payment(payment)
            except PaymentError as exc:
                raise BookingError(str(exc), status=502) from exc

        booking.status = Booking.STATUS_CANCELLED
        booking.cancelled_at = timezone.now()
        booking.cancelled_by = user
        booking.save(update_fields=['status', 'cancelled_at', 'cancelled_by', 'updated_at'])

        # A client cancelling frees the time for someone else; a host cancelling
        # means they can't make it, so the slot goes away too.
        booking.slot.status = Slot.STATUS_CANCELLED if by_host else Slot.STATUS_AVAILABLE
        booking.slot.save(update_fields=['status'])
    return booking
