from datetime import datetime, timezone as dt_timezone

import stripe
from django.conf import settings
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from bookings.models import Booking
from .models import Payment, TrainerSubscription


def _ts(value):
    """Stripe unix timestamp → aware datetime (None-safe)."""
    return datetime.fromtimestamp(value, tz=dt_timezone.utc) if value else None


class CreatePaymentIntentView(APIView):
    """POST /payments/create-intent/ {booking_id} -> {client_secret}."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if not settings.STRIPE_SECRET_KEY:
            return Response(
                {'detail': 'Payments are not configured on the server.'},
                status=status.HTTP_501_NOT_IMPLEMENTED,
            )

        booking_id = request.data.get('booking_id')
        booking = get_object_or_404(Booking, pk=booking_id, client=request.user)

        stripe.api_key = settings.STRIPE_SECRET_KEY
        intent = stripe.PaymentIntent.create(
            amount=int(booking.amount * 100),
            currency=booking.currency.lower(),
            metadata={'booking_id': str(booking.pk)},
        )

        Payment.objects.update_or_create(
            booking=booking,
            defaults={
                'stripe_payment_intent_id': intent['id'],
                'amount': booking.amount,
                'currency': booking.currency,
                'status': Payment.STATUS_PENDING,
            },
        )
        return Response({'client_secret': intent['client_secret']})


class CapturePaymentView(APIView):
    """POST /payments/bookings/<booking_id>/capture/ — confirm the charge went through."""
    permission_classes = [IsAuthenticated]

    def post(self, request, booking_id):
        if not settings.STRIPE_SECRET_KEY:
            return Response(
                {'detail': 'Payments are not configured on the server.'},
                status=status.HTTP_501_NOT_IMPLEMENTED,
            )

        booking = get_object_or_404(Booking, pk=booking_id, client=request.user)
        payment = get_object_or_404(Payment, booking=booking)

        stripe.api_key = settings.STRIPE_SECRET_KEY
        intent = stripe.PaymentIntent.retrieve(payment.stripe_payment_intent_id)

        if intent['status'] == 'succeeded':
            payment.status = Payment.STATUS_CAPTURED
            payment.save(update_fields=['status'])
            booking.status = Booking.STATUS_CONFIRMED
            booking.save(update_fields=['status', 'updated_at'])
        else:
            payment.status = Payment.STATUS_FAILED
            payment.save(update_fields=['status'])

        return Response({'status': payment.status})


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
                {'detail': 'Trainer subscriptions are not configured on the server.'},
                status=status.HTTP_501_NOT_IMPLEMENTED,
            )

        profile = getattr(request.user, 'host_profile', None)
        if profile is None:
            return Response(
                {'detail': 'Create your host profile before subscribing.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        existing = getattr(profile, 'trainer_subscription', None)
        if existing and existing.status in (
            TrainerSubscription.STATUS_ACTIVE, TrainerSubscription.STATUS_PAST_DUE,
        ):
            return Response(
                {'detail': 'This trainer already has a subscription.'},
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

        # Mark the pro tier now; visibility still waits on an *active* status,
        # which only the webhook (or a later GET) can confirm.
        if not profile.is_trainer:
            profile.is_trainer = True
            profile.save(update_fields=['is_trainer', 'updated_at'])

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
            return Response({'detail': 'No subscription found.'}, status=status.HTTP_404_NOT_FOUND)

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
        if not settings.STRIPE_WEBHOOK_SECRET:
            return Response(
                {'detail': 'Webhook secret not configured.'},
                status=status.HTTP_501_NOT_IMPLEMENTED,
            )

        try:
            event = stripe.Webhook.construct_event(
                payload=request.body,
                sig_header=request.META.get('HTTP_STRIPE_SIGNATURE', ''),
                secret=settings.STRIPE_WEBHOOK_SECRET,
            )
        except (ValueError, stripe.error.SignatureVerificationError):
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

        return Response(status=status.HTTP_200_OK)


def _settle_booking_payment(payment_intent_id, new_status):
    payment = (
        Payment.objects.select_related('booking')
        .filter(stripe_payment_intent_id=payment_intent_id)
        .first()
    )
    if payment is None or payment.status == new_status:
        return

    payment.status = new_status
    payment.save(update_fields=['status'])

    if new_status == Payment.STATUS_CAPTURED:
        booking = payment.booking
        booking.status = Booking.STATUS_CONFIRMED
        booking.save(update_fields=['status', 'updated_at'])


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
