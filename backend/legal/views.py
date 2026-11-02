"""Public pages the app and the store listings link to."""
from django.conf import settings
from django.views.generic import TemplateView

UPDATED_ON = '3 de outubro de 2026'


class NoticePage(TemplateView):
    """A short message page, e.g. where Stripe sends hosts back after sign-up."""
    template_name = 'legal/notice.html'

    def get_context_data(self, **kwargs):
        return {**super().get_context_data(**kwargs), 'support_email': settings.SUPPORT_EMAIL}


class LegalPage(TemplateView):
    def get_context_data(self, **kwargs):
        return {
            **super().get_context_data(**kwargs),
            'updated_on': UPDATED_ON,
            'support_email': settings.SUPPORT_EMAIL,
            'free_cancellation_hours': settings.FREE_CANCELLATION_HOURS,
            'payment_window_minutes': settings.BOOKING_PAYMENT_WINDOW_MINUTES,
        }
