from decimal import Decimal
from unittest import mock

import stripe
from django.test import override_settings

from acompanha_testing import ApiTestCase, make_host, make_slot, make_user
from bookings.models import Booking
from payments.models import Payment, PayoutAccount
from payments.services import refund_payment

# Real payments on: hosts must be able to receive money to be listed/booked.
stripe_on = override_settings(
    STRIPE_SECRET_KEY='sk_test_x',
    STRIPE_PUBLISHABLE_KEY='pk_test_x',
    ALLOW_UNPAID_BOOKINGS=False,
    PLATFORM_FEE_PERCENT=Decimal('15'),
)


@stripe_on
class PayoutTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.host_user = make_user('bia@test.com', display_name='Bia')
        self.host = make_host(self.host_user, price='80.00')
        self.host_api = self.client_for(self.host_user)
        self.client_api = self.client_for(make_user('ana@test.com'))

    def ready_account(self):
        return PayoutAccount.objects.create(
            host=self.host, stripe_account_id='acct_1',
            details_submitted=True, payouts_enabled=True, transfers_active=True,
        )

    def book(self):
        slot = make_slot(self.host)  # 1 hour → R$ 80
        return self.client_api.post('/api/v1/bookings/', {'slot_id': slot.pk, 'host_id': self.host.pk})

    @mock.patch('payments.connect.stripe')
    def test_onboarding_creates_the_stripe_account_once(self, stripe):
        stripe.Account.create.return_value = {'id': 'acct_1'}
        stripe.AccountLink.create.return_value = {'url': 'https://connect.stripe.com/setup/x'}
        for _ in range(2):
            r = self.host_api.post('/api/v1/payments/payouts/onboarding/')
            self.assertEqual(r.status_code, 200, r.data)
            self.assertEqual(r.data['url'], 'https://connect.stripe.com/setup/x')

        stripe.Account.create.assert_called_once()
        self.assertEqual(stripe.Account.create.call_args.kwargs['country'], 'BR')
        link = stripe.AccountLink.create.call_args.kwargs
        self.assertEqual(link['account'], 'acct_1')
        self.assertTrue(link['return_url'].endswith('/pagamentos/recebimentos/pronto/'))
        self.assertEqual(self.client.get('/pagamentos/recebimentos/pronto/').status_code, 200)

    @mock.patch('payments.connect.stripe')
    def test_status_follows_the_stripe_account(self, stripe):
        PayoutAccount.objects.create(host=self.host, stripe_account_id='acct_1')
        stripe.Account.retrieve.return_value = {
            'details_submitted': True, 'payouts_enabled': True, 'capabilities': {'transfers': 'active'},
        }
        r = self.host_api.get('/api/v1/payments/payouts/')
        self.assertEqual(r.data, {'required': True, 'connected': True, 'ready': True, 'fee_percent': 15.0})
        self.assertEqual(self.client_api.get('/api/v1/payments/payouts/').status_code, 404)  # not a host

    def test_hosts_who_cannot_be_paid_are_hidden_and_cannot_be_booked(self):
        self.assertEqual(self.client_api.get('/api/v1/profiles/hosts/').data['count'], 0)
        self.assertEqual(self.book().status_code, 409)

        self.ready_account()
        self.assertEqual(self.client_api.get('/api/v1/profiles/hosts/').data['count'], 1)
        self.assertEqual(self.book().status_code, 201)

    @mock.patch('payments.views.stripe')
    def test_payment_sends_the_host_share_and_keeps_the_fee(self, stripe):
        self.ready_account()
        booking = self.book().data
        stripe.PaymentIntent.create.return_value = {'id': 'pi_1', 'client_secret': 'cs_1'}

        r = self.client_api.post('/api/v1/payments/create-intent/', {'booking_id': booking['id']})
        self.assertEqual(r.status_code, 200, r.data)
        intent = stripe.PaymentIntent.create.call_args.kwargs
        self.assertEqual(intent['amount'], 8000)
        self.assertEqual(intent['application_fee_amount'], 1200)  # 15%
        self.assertEqual(intent['transfer_data'], {'destination': 'acct_1'})
        payment = Payment.objects.get()
        self.assertEqual((payment.platform_fee, payment.transfer_destination), (Decimal('12.00'), 'acct_1'))

    @mock.patch('payments.services.stripe')
    def test_refund_takes_back_the_host_share_and_the_fee(self, stripe):
        self.ready_account()
        booking = Booking.objects.get(pk=self.book().data['id'])
        payment = Payment.objects.create(
            booking=booking, stripe_payment_intent_id='pi_1', amount=80, currency='BRL',
            status=Payment.STATUS_CAPTURED, transfer_destination='acct_1', platform_fee=12,
        )
        refund_payment(payment)
        stripe.Refund.create.assert_called_once_with(
            payment_intent='pi_1', reverse_transfer=True, refund_application_fee=True,
        )

    @override_settings(STRIPE_WEBHOOK_SECRET='whsec_platform', STRIPE_CONNECT_WEBHOOK_SECRET='whsec_connect')
    def test_connect_webhook_updates_the_payout_account(self):
        account = PayoutAccount.objects.create(host=self.host, stripe_account_id='acct_1')
        event = {'type': 'account.updated', 'data': {'object': {
            'id': 'acct_1', 'details_submitted': True, 'payouts_enabled': True,
            'capabilities': {'transfers': 'active'},
        }}}

        def construct_event(payload, sig_header, secret):
            if secret != 'whsec_connect':  # signed by the Connect endpoint
                raise stripe.error.SignatureVerificationError('bad', sig_header)
            return event

        with mock.patch('payments.views.stripe.Webhook.construct_event', side_effect=construct_event):
            r = self.client.post('/api/v1/payments/webhook/', data=b'{}', content_type='application/json',
                                 HTTP_STRIPE_SIGNATURE='t=1,v1=x')
        self.assertEqual(r.status_code, 200)
        account.refresh_from_db()
        self.assertTrue(account.ready)
