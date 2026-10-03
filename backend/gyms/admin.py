from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import Gym

@admin.register(Gym)
class GymAdmin(ModelAdmin):
    list_display = ['name', 'city', 'member_count', 'created_at']
    search_fields = ['name', 'city']
