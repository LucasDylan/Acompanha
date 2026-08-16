"""
Fitness profile photos — extra photos a user uploads to their gym partner card.
Core fitness attributes (level, workout_types, etc.) live on the User model.
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

