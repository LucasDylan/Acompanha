"""
Host profile and photos.
"""
from django.conf import settings
from django.db import models


class HostProfile(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='host_profile')
    display_name = models.CharField(max_length=255)
    bio = models.TextField(blank=True)
    avatar = models.ImageField(upload_to='profiles/', null=True, blank=True)
    categories = models.JSONField(default=list)  # e.g. ['Coffee', 'Mentorship']
    price_per_hour = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    currency = models.CharField(max_length=3, default='USD')
    location = models.CharField(max_length=255, blank=True)
    rating = models.FloatField(null=True, blank=True)
    review_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.display_name


class ProfilePhoto(models.Model):
    profile = models.ForeignKey(HostProfile, on_delete=models.CASCADE, related_name='photos')
    photo = models.ImageField(upload_to='profiles/photos/')
    order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
