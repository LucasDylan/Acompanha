from django.urls import path

from .views import (
    CancelTrainerSubscriptionView,
    CapturePaymentView,
    CreatePaymentIntentView,
    PaymentConfigView,
    PayoutDashboardView,
    PayoutOnboardingView,
    PayoutStatusView,
    StripeWebhookView,
    TrainerSubscriptionView,
)

urlpatterns = [
    path('payments/config/', PaymentConfigView.as_view()),
    path('payments/create-intent/', CreatePaymentIntentView.as_view()),
    path('payments/bookings/<int:booking_id>/capture/', CapturePaymentView.as_view()),
    path('payments/trainer-subscription/', TrainerSubscriptionView.as_view()),
    path('payments/trainer-subscription/cancel/', CancelTrainerSubscriptionView.as_view()),
    path('payments/webhook/', StripeWebhookView.as_view()),
    path('payments/payouts/', PayoutStatusView.as_view()),
    path('payments/payouts/onboarding/', PayoutOnboardingView.as_view()),
    path('payments/payouts/dashboard/', PayoutDashboardView.as_view()),
]
