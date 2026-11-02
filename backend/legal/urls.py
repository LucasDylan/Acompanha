from django.urls import path

from .views import LegalPage, NoticePage

urlpatterns = [
    path('termos/', LegalPage.as_view(template_name='legal/terms.html'), name='terms'),
    path('privacidade/', LegalPage.as_view(template_name='legal/privacy.html'), name='privacy'),
    # Stripe's payout sign-up sends hosts back here.
    path('pagamentos/recebimentos/pronto/', NoticePage.as_view(extra_context={
        'heading': 'Tudo certo!',
        'text': 'Seus dados de recebimento foram enviados. Volte para o app Acompanha para ver o status.',
    })),
    path('pagamentos/recebimentos/expirado/', NoticePage.as_view(extra_context={
        'heading': 'O link expirou',
        'text': 'Volte para o app Acompanha e toque em "Configurar recebimentos" de novo.',
    })),
]
