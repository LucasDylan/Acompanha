from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import MatchRequest

@admin.register(MatchRequest)
class MatchRequestAdmin(ModelAdmin):
    list_display = ['sender', 'receiver', 'status', 'created_at']
    list_filter = ['status']
