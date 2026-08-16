from django.contrib import admin
from .models import MatchRequest

@admin.register(MatchRequest)
class MatchRequestAdmin(admin.ModelAdmin):
    list_display = ['sender', 'receiver', 'status', 'created_at']
    list_filter = ['status']
