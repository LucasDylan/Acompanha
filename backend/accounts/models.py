"""
User and auth models for Acompanha.
"""
import random
import string
from datetime import timedelta

from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone


class User(AbstractUser):
    FITNESS_BEGINNER = 'beginner'
    FITNESS_INTERMEDIATE = 'intermediate'
    FITNESS_ADVANCED = 'advanced'
    FITNESS_CHOICES = [
        (FITNESS_BEGINNER, 'Beginner'),
        (FITNESS_INTERMEDIATE, 'Intermediate'),
        (FITNESS_ADVANCED, 'Advanced'),
    ]

    display_name = models.CharField(max_length=255, blank=True)
    avatar_url = models.URLField(blank=True)
    facebook_id = models.CharField(max_length=64, null=True, blank=True, unique=True)

    # Gym membership — nullable until user completes onboarding
    gym = models.ForeignKey(
        'gyms.Gym',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='members',
    )

    # Fitness profile fields
    fitness_level = models.CharField(
        max_length=16,
        choices=FITNESS_CHOICES,
        default=FITNESS_BEGINNER,
    )
    # Comma-separated workout types, e.g. "Musculação,Cardio,CrossFit"
    workout_types = models.JSONField(default=list)
    # Days available, e.g. ["Mon", "Wed", "Fri"]
    available_days = models.JSONField(default=list)
    bio = models.TextField(blank=True)
    age = models.PositiveSmallIntegerField(null=True, blank=True)

    def __str__(self):
        return self.display_name or self.email


class PasswordResetCode(models.Model):
    """A short-lived numeric code emailed to a user to authorize a password reset."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='password_reset_codes')
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    used = models.BooleanField(default=False)

    def is_valid(self):
        return not self.used and timezone.now() - self.created_at < timedelta(minutes=15)

    @staticmethod
    def generate_code():
        return ''.join(random.choices(string.digits, k=6))
