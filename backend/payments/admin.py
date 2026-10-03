from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import Payment, TrainerSubscription


@admin.register(Payment)
class PaymentAdmin(ModelAdmin):
    list_display = ['booking', 'amount', 'currency', 'status', 'created_at']
    list_filter = ['status']
    search_fields = ['stripe_payment_intent_id']
    raw_id_fields = ['booking']


@admin.register(TrainerSubscription)
class TrainerSubscriptionAdmin(ModelAdmin):
    list_display = ['host', 'status', 'current_period_end', 'cancel_at_period_end']
    list_filter = ['status']
    raw_id_fields = ['host']
