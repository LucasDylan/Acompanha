"""
User and auth models for GymBuddy.
"""
from django.contrib.auth.models import AbstractUser
from django.db import models


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
