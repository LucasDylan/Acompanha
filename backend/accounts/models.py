"""
User and auth models.
"""
from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    ROLE_CLIENT = 'client'
    ROLE_HOST = 'host'
    ROLE_BOTH = 'both'
    ROLE_CHOICES = [
        (ROLE_CLIENT, 'Client'),
        (ROLE_HOST, 'Host'),
        (ROLE_BOTH, 'Both'),
    ]

    role = models.CharField(max_length=16, choices=ROLE_CHOICES, default=ROLE_CLIENT)
    display_name = models.CharField(max_length=255, blank=True)
    avatar_url = models.URLField(blank=True)
