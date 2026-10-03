"""
Training sessions — agreed workout sessions between matched gym partners.
Bookings — paid meetings with a host, one per time slot.
"""
from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models import Avg, Count, Q


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
    ACTIVE_STATUSES = [STATUS_PENDING, STATUS_CONFIRMED, STATUS_COMPLETED, STATUS_DISPUTED]

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
    # A slot can be booked again after a cancellation, so this is a plain FK
    # guarded by the "one active booking per slot" constraint below.
    slot = models.ForeignKey(
        'profiles.Slot',
        on_delete=models.CASCADE,
        related_name='bookings',
    )
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default=STATUS_PENDING)
    amount = models.DecimalField(max_digits=8, decimal_places=2)
    currency = models.CharField(max_length=8, default='BRL')
    cancelled_at = models.DateTimeField(null=True, blank=True)
    cancelled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='+',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        constraints = [
            models.UniqueConstraint(
                fields=['slot'],
                condition=Q(status__in=['pending', 'confirmed', 'completed', 'disputed']),
                name='one_active_booking_per_slot',
            ),
        ]

    def __str__(self):
        return f'Booking {self.pk}: {self.client} -> {self.host}'


class Review(models.Model):
    """A client's rating of a meeting that happened. Feeds the host's rating."""
    booking = models.OneToOneField(Booking, on_delete=models.CASCADE, related_name='review')
    rating = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField(blank=True, max_length=1000)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.rating}★ for booking {self.booking_id}'

    @staticmethod
    def refresh_host_rating(host):
        stats = Review.objects.filter(booking__host=host).aggregate(avg=Avg('rating'), n=Count('id'))
        host.rating = round(stats['avg'], 2) if stats['avg'] is not None else None
        host.review_count = stats['n']
        host.save(update_fields=['rating', 'review_count', 'updated_at'])
