"""
Payment records and Stripe integration.
"""
from django.conf import settings
from django.db import models
from bookings.models import Booking


class Payment(models.Model):
    STATUS_PENDING = 'pending'
    STATUS_CAPTURED = 'captured'
    STATUS_REFUNDED = 'refunded'
    STATUS_FAILED = 'failed'

    booking = models.OneToOneField(Booking, on_delete=models.PROTECT, related_name='payment')
    stripe_payment_intent_id = models.CharField(max_length=255)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    currency = models.CharField(max_length=3, default='USD')
    status = models.CharField(max_length=16, default=STATUS_PENDING)
    # Destination charge: the host's Stripe account receives amount - platform_fee.
    transfer_destination = models.CharField(max_length=255, blank=True)
    platform_fee = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)


class PayoutAccount(models.Model):
    """The host's Stripe Express account, where their share of each booking goes.

    Stripe runs the sign-up (identity, bank account); the flags mirror the
    account and are kept in sync by the app's status check and the webhook.
    """
    host = models.OneToOneField(
        'profiles.HostProfile',
        on_delete=models.CASCADE,
        related_name='payout_account',
    )
    stripe_account_id = models.CharField(max_length=255, unique=True)
    details_submitted = models.BooleanField(default=False)
    payouts_enabled = models.BooleanField(default=False)
    transfers_active = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    @property
    def ready(self):
        return self.details_submitted and self.payouts_enabled and self.transfers_active

    def __str__(self):
        return f'{self.host} — {self.stripe_account_id}'


class TrainerSubscription(models.Model):
    """A personal trainer's recurring Pro plan — what keeps them listed in Discovery.

    Status mirrors Stripe's subscription status and is kept in sync by the
    webhook, so a trainer who paid never silently stays invisible.
    """
    STATUS_INCOMPLETE = 'incomplete'
    STATUS_ACTIVE = 'active'
    STATUS_PAST_DUE = 'past_due'
    STATUS_CANCELED = 'canceled'
    STATUS_UNPAID = 'unpaid'
    STATUS_CHOICES = [
        (STATUS_INCOMPLETE, 'Incomplete'),
        (STATUS_ACTIVE, 'Active'),
        (STATUS_PAST_DUE, 'Past due'),
        (STATUS_CANCELED, 'Canceled'),
        (STATUS_UNPAID, 'Unpaid'),
    ]

    host = models.OneToOneField(
        'profiles.HostProfile',
        on_delete=models.CASCADE,
        related_name='trainer_subscription',
    )
    stripe_customer_id = models.CharField(max_length=255)
    stripe_subscription_id = models.CharField(max_length=255, db_index=True)
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default=STATUS_INCOMPLETE)
    current_period_end = models.DateTimeField(null=True, blank=True)
    cancel_at_period_end = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @property
    def is_active(self):
        return self.status == self.STATUS_ACTIVE

    def __str__(self):
        return f'{self.host} — {self.status}'
