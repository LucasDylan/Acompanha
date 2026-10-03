from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import Conversation, Message


@admin.register(Conversation)
class ConversationAdmin(ModelAdmin):
    list_display = ['id', 'user_a', 'user_b', 'last_message_at']
    raw_id_fields = ['user_a', 'user_b']


@admin.register(Message)
class MessageAdmin(ModelAdmin):
    list_display = ['id', 'conversation', 'sender', 'created_at']
    search_fields = ['text']
    raw_id_fields = ['conversation', 'sender']
