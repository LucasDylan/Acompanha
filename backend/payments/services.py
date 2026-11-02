import stripe
from django.conf import settings

from .models import Payment


class PaymentError(Exception):
    pass


def stripe_enabled():
    return bool(settings.STRIPE_SECRET_KEY)


def captured_payment(booking):
    """The booking's payment if money was actually taken, else None."""
    return Payment.objects.filter(booking=booking, status=Payment.STATUS_CAPTURED).first()


def refund_payment(payment):
    """Full refund through Stripe. Raises PaymentError if Stripe refuses it, so
    the caller can keep the booking as it was instead of cancelling unpaid back."""
    if not stripe_enabled():
        raise PaymentError('Pagamentos não estão configurados no servidor.')
    stripe.api_key = settings.STRIPE_SECRET_KEY
    params = {'payment_intent': payment.stripe_payment_intent_id}
    if payment.transfer_destination:
        # Take the host's share back and return the platform fee too.
        params.update(reverse_transfer=True, refund_application_fee=True)
    try:
        stripe.Refund.create(**params)
    except stripe.error.StripeError as exc:
        raise PaymentError('Não foi possível estornar o pagamento agora. Tente novamente.') from exc
    payment.status = Payment.STATUS_REFUNDED
    payment.save(update_fields=['status'])
