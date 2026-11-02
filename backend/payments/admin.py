from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import Payment, PayoutAccount, TrainerSubscription


@admin.register(Payment)
class PaymentAdmin(ModelAdmin):
    list_display = ['booking', 'amount', 'platform_fee', 'currency', 'status', 'created_at']
    list_filter = ['status']
    search_fields = ['stripe_payment_intent_id']
    raw_id_fields = ['booking']


@admin.register(TrainerSubscription)
class TrainerSubscriptionAdmin(ModelAdmin):
    list_display = ['host', 'status', 'current_period_end', 'cancel_at_period_end']
    list_filter = ['status']
    raw_id_fields = ['host']


@admin.register(PayoutAccount)
class PayoutAccountAdmin(ModelAdmin):
    list_display = ['host', 'stripe_account_id', 'details_submitted', 'payouts_enabled', 'transfers_active', 'updated_at']
    list_filter = ['payouts_enabled']
    search_fields = ['stripe_account_id', 'host__display_name', 'host__user__email']
    raw_id_fields = ['host']
