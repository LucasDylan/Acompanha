from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import FitnessProfilePhoto, HostProfile, ProfilePhoto, Slot


@admin.register(HostProfile)
class HostProfileAdmin(ModelAdmin):
    list_display = ['display_name', 'user', 'location', 'price_per_hour', 'is_trainer', 'is_active']
    list_filter = ['is_active', 'is_trainer']
    search_fields = ['display_name', 'user__email', 'location']
    raw_id_fields = ['user']


@admin.register(Slot)
class SlotAdmin(ModelAdmin):
    list_display = ['host', 'start_at', 'end_at', 'status']
    list_filter = ['status']
    raw_id_fields = ['host']


admin.site.register(ProfilePhoto, ModelAdmin)
admin.site.register(FitnessProfilePhoto, ModelAdmin)
