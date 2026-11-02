from django.test import TestCase


class LegalPagesTests(TestCase):
    def test_terms_and_privacy_are_public(self):
        terms = self.client.get('/termos/')
        self.assertContains(terms, 'Regras da comunidade')
        self.assertContains(terms, 'pelo menos 24 horas')  # FREE_CANCELLATION_HOURS
        privacy = self.client.get('/privacidade/')
        self.assertContains(privacy, 'Lei Geral de Proteção de Dados')
        self.assertContains(privacy, 'suporte@acompanha.app')
