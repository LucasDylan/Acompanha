from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import Booking, Review, TrainingSession


@admin.register(TrainingSession)
class TrainingSessionAdmin(ModelAdmin):
    list_display = ['initiator', 'partner', 'scheduled_at', 'status']
    list_filter = ['status']


@admin.register(Booking)
class BookingAdmin(ModelAdmin):
    list_display = ['id', 'client', 'host', 'slot', 'status', 'amount', 'created_at']
    list_filter = ['status']
    search_fields = ['client__email', 'host__display_name']
    raw_id_fields = ['client', 'host', 'slot', 'cancelled_by']


@admin.register(Review)
class ReviewAdmin(ModelAdmin):
    list_display = ['booking', 'rating', 'created_at']
    list_filter = ['rating']
