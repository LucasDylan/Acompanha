"""
Fitness profile photos — extra photos a user uploads to their gym partner card.
Core fitness attributes (level, workout_types, etc.) live on the User model.

HostProfile / ProfilePhoto / Slot below back the *paid* personal-trainer
marketplace ("Discovery" tab): a user opts in as a host by creating a
HostProfile, sets an hourly price, and publishes bookable time slots.
"""
from django.conf import settings
from django.db import models


class FitnessProfilePhoto(models.Model):
    """Extra photos a user adds to their partner profile card."""
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='profile_photos',
    )
    photo = models.ImageField(upload_to='profiles/photos/')
    order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order', 'created_at']

    def __str__(self):
        return f'Photo {self.pk} for {self.user}'


class HostProfile(models.Model):
    """A paid personal-trainer marketplace listing for a user."""
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='host_profile',
    )
    display_name = models.CharField(max_length=255, blank=True)
    bio = models.TextField(blank=True)
    categories = models.JSONField(default=list)
    # Professional personal trainers are labelled as such in the app and only
    # appear in Discovery while their Pro subscription is active. Anyone can be
    # a host regardless of this flag — it marks the professional tier, nothing else.
    is_trainer = models.BooleanField(default=False)
    price_per_hour = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    currency = models.CharField(max_length=8, default='BRL')
    location = models.CharField(max_length=255, blank=True)
    rating = models.DecimalField(max_digits=3, decimal_places=2, null=True, blank=True)
    review_count = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.display_name or str(self.user)


class ProfilePhoto(models.Model):
    """A gallery photo attached to a host's marketplace listing."""
    host_profile = models.ForeignKey(
        HostProfile,
        on_delete=models.CASCADE,
        related_name='photos',
    )
    photo = models.ImageField(upload_to='hosts/photos/')
    order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order', 'created_at']

    def __str__(self):
        return f'Photo {self.pk} for {self.host_profile}'


class Slot(models.Model):
    """A bookable time slot published by a host."""
    STATUS_AVAILABLE = 'available'
    STATUS_BOOKED = 'booked'
    STATUS_PAST = 'past'
    STATUS_CANCELLED = 'cancelled'
    STATUS_CHOICES = [
        (STATUS_AVAILABLE, 'Available'),
        (STATUS_BOOKED, 'Booked'),
        (STATUS_PAST, 'Past'),
        (STATUS_CANCELLED, 'Cancelled'),
    ]

    host = models.ForeignKey(HostProfile, on_delete=models.CASCADE, related_name='slots')
    start_at = models.DateTimeField()
    end_at = models.DateTimeField()
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default=STATUS_AVAILABLE)

    class Meta:
        ordering = ['start_at']

    def __str__(self):
        return f'{self.host} @ {self.start_at:%Y-%m-%d %H:%M}'
