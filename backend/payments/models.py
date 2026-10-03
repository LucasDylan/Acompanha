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
    created_at = models.DateTimeField(auto_now_add=True)


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
