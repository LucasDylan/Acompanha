"""
Paying hosts with Stripe Connect.

Each host gets a Stripe Express account (Stripe collects their identity and
bank details). Bookings are destination charges: the client pays once, the
host's account receives the amount minus PLATFORM_FEE_PERCENT, and a refund
reverses both parts.
"""
from decimal import ROUND_HALF_UP, Decimal

import stripe
from django.conf import settings
from django.db.models import Q

from .models import PayoutAccount

# Hosts whose payout account can receive money (for HostProfile querysets).
READY_HOSTS = Q(
    payout_account__details_submitted=True,
    payout_account__payouts_enabled=True,
    payout_account__transfers_active=True,
)


def payouts_required():
    """Real payments are on, so a host must be able to receive them before
    being listed or booked. Off in development without Stripe keys."""
    return bool(settings.STRIPE_SECRET_KEY) and not settings.ALLOW_UNPAID_BOOKINGS


def host_can_receive(host):
    account = getattr(host, 'payout_account', None)
    return account is not None and account.ready


def platform_fee(amount):
    return (Decimal(amount) * settings.PLATFORM_FEE_PERCENT / 100).quantize(
        Decimal('0.01'), rounding=ROUND_HALF_UP,
    )


def _stripe():
    stripe.api_key = settings.STRIPE_SECRET_KEY
    return stripe


def onboarding_link(host, return_url, refresh_url):
    """Link to Stripe's sign-up for [host], creating their account the first time."""
    s = _stripe()
    account = PayoutAccount.objects.filter(host=host).first()
    if account is None:
        created = s.Account.create(
            type='express',
            country='BR',
            email=host.user.email,
            business_type='individual',
            capabilities={'card_payments': {'requested': True}, 'transfers': {'requested': True}},
            metadata={'host_profile_id': str(host.pk)},
        )
        account = PayoutAccount.objects.create(host=host, stripe_account_id=created['id'])
    link = s.AccountLink.create(
        account=account.stripe_account_id,
        type='account_onboarding',
        return_url=return_url,
        refresh_url=refresh_url,
    )
    return link['url']


def sync_account(account, stripe_account=None):
    """Copies Stripe's view of the account (fetched unless given) to [account]."""
    data = stripe_account or _stripe().Account.retrieve(account.stripe_account_id)
    account.details_submitted = bool(data.get('details_submitted'))
    account.payouts_enabled = bool(data.get('payouts_enabled'))
    account.transfers_active = (data.get('capabilities') or {}).get('transfers') == 'active'
    account.save(update_fields=['details_submitted', 'payouts_enabled', 'transfers_active', 'updated_at'])
    return account


def dashboard_link(account):
    """Stripe Express dashboard: balance, payouts and bank details."""
    return _stripe().Account.create_login_link(account.stripe_account_id)['url']
