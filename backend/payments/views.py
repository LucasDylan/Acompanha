from datetime import datetime, timezone as dt_timezone

import stripe
from django.conf import settings
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from bookings.models import Booking
from bookings.services import expire_unpaid_bookings
from .connect import (
    dashboard_link, host_can_receive, onboarding_link, payouts_required, platform_fee, sync_account,
)
from .models import Payment, PayoutAccount, TrainerSubscription
from .services import PaymentError, refund_payment

# A pro trainer keeps the label while Stripe retries a failed renewal.
TRAINER_LABEL_STATUSES = (TrainerSubscription.STATUS_ACTIVE, TrainerSubscription.STATUS_PAST_DUE)


def _ts(value):
    """Stripe unix timestamp → aware datetime (None-safe)."""
    return datetime.fromtimestamp(value, tz=dt_timezone.utc) if value else None


class PaymentConfigView(APIView):
    """GET /payments/config/ — what the app needs to start Stripe's payment sheet."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response({
            'enabled': bool(settings.STRIPE_SECRET_KEY and settings.STRIPE_PUBLISHABLE_KEY),
            'publishable_key': settings.STRIPE_PUBLISHABLE_KEY or None,
            'unpaid_bookings_allowed': settings.ALLOW_UNPAID_BOOKINGS,
        })


class CreatePaymentIntentView(APIView):
    """POST /payments/create-intent/ {booking_id} -> {client_secret}."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if not settings.STRIPE_SECRET_KEY:
            return Response(
                {'detail': 'Pagamentos ainda não estão configurados no servidor.'},
                status=status.HTTP_501_NOT_IMPLEMENTED,
            )

        expire_unpaid_bookings()
        booking_id = request.data.get('booking_id')
        booking = get_object_or_404(Booking, pk=booking_id, client=request.user)
        if booking.status != Booking.STATUS_PENDING:
            return Response(
                {'detail': 'Esta reserva não está aguardando pagamento.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        stripe.api_key = settings.STRIPE_SECRET_KEY
        # Retrying payment reuses the same intent, so a customer can never be
        # charged twice for one booking.
        existing = Payment.objects.filter(booking=booking).first()
        if existing and existing.status == Payment.STATUS_PENDING:
            intent = stripe.PaymentIntent.retrieve(existing.stripe_payment_intent_id)
            if intent['status'] not in ('canceled', 'succeeded'):
                return Response({'client_secret': intent['client_secret']})

        # Destination charge: the host's share goes straight to their account.
        split, fee, destination = {}, None, ''
        if payouts_required():
            if not host_can_receive(booking.host):
                return Response(
                    {'detail': 'Este anfitrião ainda não pode receber pagamentos pelo app.'},
                    status=status.HTTP_409_CONFLICT,
                )
            fee = platform_fee(booking.amount)
            destination = booking.host.payout_account.stripe_account_id
            split = {'transfer_data': {'destination': destination}, 'application_fee_amount': int(fee * 100)}

        intent = stripe.PaymentIntent.create(
            amount=int(booking.amount * 100),
            currency=booking.currency.lower(),
            metadata={'booking_id': str(booking.pk)},
            automatic_payment_methods={'enabled': True},
            **split,
        )

        Payment.objects.update_or_create(
            booking=booking,
            defaults={
                'stripe_payment_intent_id': intent['id'],
                'amount': booking.amount,
                'currency': booking.currency,
                'status': Payment.STATUS_PENDING,
                'transfer_destination': destination,
                'platform_fee': fee,
            },
        )
        return Response({'client_secret': intent['client_secret']})


def _own_host_profile(request):
    return getattr(request.user, 'host_profile', None)


class PayoutStatusView(APIView):
    """GET /payments/payouts/ — can the caller (a host) receive payments?"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        host = _own_host_profile(request)
        if host is None:
            return Response({'detail': 'Crie seu perfil de anfitrião primeiro.'}, status=status.HTTP_404_NOT_FOUND)
        account = PayoutAccount.objects.filter(host=host).first()
        if account is not None and settings.STRIPE_SECRET_KEY:
            try:
                sync_account(account)
            except stripe.error.StripeError:
                pass  # Show the last known state.
        return Response({
            'required': payouts_required(),
            'connected': account is not None,
            'ready': bool(account and account.ready),
            'fee_percent': float(settings.PLATFORM_FEE_PERCENT),
        })


class PayoutOnboardingView(APIView):
    """POST /payments/payouts/onboarding/ -> {url} of Stripe's sign-up for
    receiving payments (identity and bank account)."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if not settings.STRIPE_SECRET_KEY:
            return Response(
                {'detail': 'Pagamentos ainda não estão configurados no servidor.'},
                status=status.HTTP_501_NOT_IMPLEMENTED,
            )
        host = _own_host_profile(request)
        if host is None:
            return Response({'detail': 'Crie seu perfil de anfitrião primeiro.'}, status=status.HTTP_404_NOT_FOUND)
        try:
            url = onboarding_link(
                host,
                return_url=request.build_absolute_uri('/pagamentos/recebimentos/pronto/'),
                refresh_url=request.build_absolute_uri('/pagamentos/recebimentos/expirado/'),
            )
        except stripe.error.StripeError:
            return Response(
                {'detail': 'Não foi possível abrir o cadastro de recebimentos agora. Tente novamente.'},
                status=status.HTTP_502_BAD_GATEWAY,
            )
        return Response({'url': url})


class PayoutDashboardView(APIView):
    """POST /payments/payouts/dashboard/ -> {url} of the host's Stripe dashboard
    (balance, payouts, bank details)."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        host = _own_host_profile(request)
        account = PayoutAccount.objects.filter(host=host).first() if host else None
        if account is None or not account.details_submitted or not settings.STRIPE_SECRET_KEY:
            return Response(
                {'detail': 'Termine o cadastro de recebimentos primeiro.'}, status=status.HTTP_409_CONFLICT,
            )
        try:
            return Response({'url': dashboard_link(account)})
        except stripe.error.StripeError:
            return Response(
                {'detail': 'Não foi possível abrir seus recebimentos agora. Tente novamente.'},
                status=status.HTTP_502_BAD_GATEWAY,
            )


class CapturePaymentView(APIView):
    """POST /payments/bookings/<booking_id>/capture/ — called by the app right
    after the payment sheet succeeds; the webhook is the fallback."""
    permission_classes = [IsAuthenticated]

    def post(self, request, booking_id):
        if not settings.STRIPE_SECRET_KEY:
            return Response(
                {'detail': 'Pagamentos ainda não estão configurados no servidor.'},
                status=status.HTTP_501_NOT_IMPLEMENTED,
            )

        booking = get_object_or_404(Booking, pk=booking_id, client=request.user)
        payment = get_object_or_404(Payment, booking=booking)

        stripe.api_key = settings.STRIPE_SECRET_KEY
        intent = stripe.PaymentIntent.retrieve(payment.stripe_payment_intent_id)

        if intent['status'] == 'succeeded':
            _settle_booking_payment(payment.stripe_payment_intent_id, Payment.STATUS_CAPTURED)
            payment.refresh_from_db()
            booking.refresh_from_db()
            if booking.status == Booking.STATUS_CANCELLED:
                return Response(
                    {'detail': 'O tempo para pagar esta reserva acabou e o valor foi estornado. '
                               'Escolha o horário de novo.',
                     'status': payment.status},
                    status=status.HTTP_409_CONFLICT,
                )
        elif intent['status'] in ('requires_payment_method', 'canceled'):
            payment.status = Payment.STATUS_FAILED
            payment.save(update_fields=['status'])

        return Response({'status': payment.status, 'booking_status': booking.status})


class TrainerSubscriptionView(APIView):
    """GET  /payments/trainer-subscription/  — the caller's Pro plan status.
    POST /payments/trainer-subscription/  — start it, returns a client_secret
    the app confirms with the Stripe SDK.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = getattr(request.user, 'host_profile', None)
        sub = getattr(profile, 'trainer_subscription', None) if profile else None
        if sub is None:
            return Response({'status': None, 'is_trainer': bool(profile and profile.is_trainer)})
        return Response({
            'status': sub.status,
            'is_trainer': profile.is_trainer,
            'current_period_end': sub.current_period_end,
            'cancel_at_period_end': sub.cancel_at_period_end,
        })

    def post(self, request):
        if not settings.STRIPE_SECRET_KEY or not settings.STRIPE_TRAINER_PRICE_ID:
            return Response(
                {'detail': 'O plano Pro ainda não está configurado no servidor.'},
                status=status.HTTP_501_NOT_IMPLEMENTED,
            )

        profile = getattr(request.user, 'host_profile', None)
        if profile is None:
            return Response(
                {'detail': 'Crie seu perfil de anfitrião antes de assinar.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        existing = getattr(profile, 'trainer_subscription', None)
        if existing and existing.status in (
            TrainerSubscription.STATUS_ACTIVE, TrainerSubscription.STATUS_PAST_DUE,
        ):
            return Response(
                {'detail': 'Você já tem uma assinatura ativa.'},
                status=status.HTTP_409_CONFLICT,
            )

        stripe.api_key = settings.STRIPE_SECRET_KEY

        if existing and existing.stripe_customer_id:
            customer_id = existing.stripe_customer_id
        else:
            customer = stripe.Customer.create(
                email=request.user.email,
                name=profile.display_name or request.user.get_username(),
                metadata={'host_profile_id': str(profile.pk), 'user_id': str(request.user.pk)},
            )
            customer_id = customer['id']

        subscription = stripe.Subscription.create(
            customer=customer_id,
            items=[{'price': settings.STRIPE_TRAINER_PRICE_ID}],
            payment_behavior='default_incomplete',
            payment_settings={'save_default_payment_method': 'on_subscription'},
            expand=['latest_invoice.payment_intent'],
            metadata={'host_profile_id': str(profile.pk)},
        )

        # The pro label is only switched on once Stripe reports the plan active
        # (see _sync_trainer_subscription) — abandoning checkout changes nothing.
        TrainerSubscription.objects.update_or_create(
            host=profile,
            defaults={
                'stripe_customer_id': customer_id,
                'stripe_subscription_id': subscription['id'],
                'status': subscription['status'],
                'current_period_end': _ts(subscription.get('current_period_end')),
                'cancel_at_period_end': bool(subscription.get('cancel_at_period_end')),
            },
        )

        intent = (subscription.get('latest_invoice') or {}).get('payment_intent') or {}
        return Response({
            'subscription_id': subscription['id'],
            'status': subscription['status'],
            'client_secret': intent.get('client_secret'),
        })


class CancelTrainerSubscriptionView(APIView):
    """POST /payments/trainer-subscription/cancel/ — stops renewal at period end.

    The trainer stays listed until the period they already paid for runs out.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        profile = getattr(request.user, 'host_profile', None)
        sub = getattr(profile, 'trainer_subscription', None) if profile else None
        if sub is None:
            return Response({'detail': 'Nenhuma assinatura encontrada.'}, status=status.HTTP_404_NOT_FOUND)
        if not settings.STRIPE_SECRET_KEY:
            return Response(
                {'detail': 'Pagamentos ainda não estão configurados no servidor.'},
                status=status.HTTP_501_NOT_IMPLEMENTED,
            )

        stripe.api_key = settings.STRIPE_SECRET_KEY
        stripe.Subscription.modify(sub.stripe_subscription_id, cancel_at_period_end=True)

        sub.cancel_at_period_end = True
        sub.save(update_fields=['cancel_at_period_end', 'updated_at'])
        return Response({'status': sub.status, 'cancel_at_period_end': True})


class StripeWebhookView(APIView):
    """POST /payments/webhook/ — Stripe's source of truth for payment state.

    Signature-verified and unauthenticated (Stripe carries no JWT). This is what
    keeps a paid trainer from staying invisible when the app dies mid-checkout.
    """
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        # Two endpoints can point here: the platform's own events and the
        # connected accounts' ones, each with its own signing secret.
        secrets = [s for s in (settings.STRIPE_WEBHOOK_SECRET, settings.STRIPE_CONNECT_WEBHOOK_SECRET) if s]
        if not secrets:
            return Response(
                {'detail': 'Webhook secret not configured.'},
                status=status.HTTP_501_NOT_IMPLEMENTED,
            )

        event = None
        for secret in secrets:
            try:
                event = stripe.Webhook.construct_event(
                    payload=request.body,
                    sig_header=request.META.get('HTTP_STRIPE_SIGNATURE', ''),
                    secret=secret,
                )
                break
            except stripe.error.SignatureVerificationError:
                continue
            except ValueError:
                break
        if event is None:
            return Response({'detail': 'Invalid signature.'}, status=status.HTTP_400_BAD_REQUEST)

        obj = event['data']['object']
        kind = event['type']

        if kind == 'payment_intent.succeeded':
            _settle_booking_payment(obj['id'], Payment.STATUS_CAPTURED)
        elif kind == 'payment_intent.payment_failed':
            _settle_booking_payment(obj['id'], Payment.STATUS_FAILED)
        elif kind in ('customer.subscription.created',
                      'customer.subscription.updated',
                      'customer.subscription.deleted'):
            _sync_trainer_subscription(obj)
        elif kind == 'account.updated':
            account = PayoutAccount.objects.filter(stripe_account_id=obj['id']).first()
            if account is not None:
                sync_account(account, obj)

        return Response(status=status.HTTP_200_OK)


def _settle_booking_payment(payment_intent_id, new_status):
    payment = (
        Payment.objects.select_related('booking')
        .filter(stripe_payment_intent_id=payment_intent_id)
        .first()
    )
    if payment is None or payment.status in (new_status, Payment.STATUS_REFUNDED):
        return

    payment.status = new_status
    payment.save(update_fields=['status'])

    if new_status != Payment.STATUS_CAPTURED:
        return
    booking = payment.booking
    if booking.status == Booking.STATUS_PENDING:
        booking.status = Booking.STATUS_CONFIRMED
        booking.save(update_fields=['status', 'updated_at'])
    elif booking.status == Booking.STATUS_CANCELLED:
        # Paid after the hold ran out (or after cancelling): give it back.
        try:
            refund_payment(payment)
        except PaymentError:
            pass  # Stays "captured" so it shows up for a manual refund in the admin.


def _sync_trainer_subscription(stripe_subscription):
    sub = TrainerSubscription.objects.filter(
        stripe_subscription_id=stripe_subscription['id'],
    ).first()
    if sub is None:
        return

    sub.status = stripe_subscription['status']
    sub.cancel_at_period_end = bool(stripe_subscription.get('cancel_at_period_end'))
    period_end = _ts(stripe_subscription.get('current_period_end'))
    if period_end:
        sub.current_period_end = period_end
    sub.save(update_fields=[
        'status', 'cancel_at_period_end', 'current_period_end', 'updated_at',
    ])

    host = sub.host
    is_trainer = sub.status in TRAINER_LABEL_STATUSES
    if host.is_trainer != is_trainer:
        host.is_trainer = is_trainer
        host.save(update_fields=['is_trainer', 'updated_at'])
