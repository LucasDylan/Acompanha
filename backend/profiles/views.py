from rest_framework import generics
from django.shortcuts import get_object_or_404

from .models import HostProfile, ProfilePhoto
from .serializers import HostProfileSerializer

# Placeholder - full implementation would list/filter hosts
# For MVP, profiles app can return empty or mock data
