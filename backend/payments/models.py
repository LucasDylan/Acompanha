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
