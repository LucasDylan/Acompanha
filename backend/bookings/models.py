"""
Training sessions — agreed workout sessions between matched gym partners.
"""
from django.conf import settings
from django.db import models


class TrainingSession(models.Model):
    STATUS_PENDING = 'pending'
    STATUS_CONFIRMED = 'confirmed'
    STATUS_COMPLETED = 'completed'
    STATUS_CANCELLED = 'cancelled'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending'),
        (STATUS_CONFIRMED, 'Confirmed'),
        (STATUS_COMPLETED, 'Completed'),
        (STATUS_CANCELLED, 'Cancelled'),
    ]

    initiator = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='initiated_sessions',
    )
    partner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='partner_sessions',
    )
    gym = models.ForeignKey(
        'gyms.Gym',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='sessions',
    )
    scheduled_at = models.DateTimeField()
    duration_minutes = models.PositiveIntegerField(default=60)
    workout_type = models.CharField(max_length=100, blank=True)
    notes = models.TextField(blank=True)
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default=STATUS_PENDING)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['scheduled_at']

    def __str__(self):
        return f'{self.initiator} + {self.partner} @ {self.scheduled_at:%Y-%m-%d %H:%M}'


class Booking(models.Model):
    """A paid booking of a host's time slot (the marketplace/Discovery flow)."""
    STATUS_PENDING = 'pending'
    STATUS_CONFIRMED = 'confirmed'
    STATUS_COMPLETED = 'completed'
    STATUS_CANCELLED = 'cancelled'
    STATUS_DISPUTED = 'disputed'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending'),
        (STATUS_CONFIRMED, 'Confirmed'),
        (STATUS_COMPLETED, 'Completed'),
        (STATUS_CANCELLED, 'Cancelled'),
        (STATUS_DISPUTED, 'Disputed'),
    ]

    client = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='client_bookings',
    )
    host = models.ForeignKey(
        'profiles.HostProfile',
        on_delete=models.CASCADE,
        related_name='bookings',
    )
    slot = models.OneToOneField(
        'profiles.Slot',
        on_delete=models.CASCADE,
        related_name='booking',
    )
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default=STATUS_PENDING)
    amount = models.DecimalField(max_digits=8, decimal_places=2)
    currency = models.CharField(max_length=8, default='BRL')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Booking {self.pk}: {self.client} -> {self.host}'

