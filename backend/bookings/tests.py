from datetime import timedelta
from unittest import mock

from django.test import override_settings
from django.utils import timezone

from acompanha_testing import ApiTestCase, make_host, make_slot, make_user
from payments.models import Payment
from profiles.models import Slot

from .models import Booking, Review


@override_settings(ALLOW_UNPAID_BOOKINGS=False, STRIPE_SECRET_KEY='')
class BookingRulesTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.host_user = make_user('host@test.com', display_name='Host')
        self.host = make_host(self.host_user, price='80.00')
        self.client_user = make_user('client@test.com')
        self.api = self.client_for(self.client_user)

    def book(self, slot, api=None):
        return (api or self.api).post(
            '/api/v1/bookings/', {'slot_id': slot.pk, 'host_id': self.host.pk}, format='json',
        )

    def test_charges_price_times_duration_and_waits_for_payment(self):
        slot = make_slot(self.host, hours=2)
        r = self.book(slot)
        self.assertEqual(r.status_code, 201, r.data)
        self.assertEqual(r.data['amount'], 160.0)
        self.assertEqual(r.data['status'], 'pending')
        slot.refresh_from_db()
        self.assertEqual(slot.status, Slot.STATUS_BOOKED)

    @override_settings(ALLOW_UNPAID_BOOKINGS=True)
    def test_dev_mode_confirms_without_payment(self):
        r = self.book(make_slot(self.host))
        self.assertEqual(r.data['status'], 'confirmed')

    def test_cannot_book_a_past_slot(self):
        slot = make_slot(self.host, starts_in=-timedelta(hours=2))
        r = self.book(slot)
        self.assertEqual(r.status_code, 400)
        self.assertFalse(Booking.objects.exists())

    def test_cannot_book_own_slot(self):
        r = self.book(make_slot(self.host), api=self.client_for(self.host_user))
        self.assertEqual(r.status_code, 400)

    def test_cannot_book_a_taken_slot(self):
        slot = make_slot(self.host)
        self.book(slot)
        other = self.client_for(make_user('other@test.com'))
        self.assertEqual(self.book(slot, api=other).status_code, 400)

    def test_slot_can_be_booked_again_after_cancellation(self):
        slot = make_slot(self.host)
        first = self.book(slot)
        self.api.post(f"/api/v1/bookings/{first.data['id']}/cancel/")
        other = self.client_for(make_user('other@test.com'))
        r = self.book(slot, api=other)
        self.assertEqual(r.status_code, 201, r.data)

    def test_confirm_endpoint_is_gone(self):
        r = self.book(make_slot(self.host))
        confirm = self.api.post(f"/api/v1/bookings/{r.data['id']}/confirm/")
        self.assertEqual(confirm.status_code, 404)
        self.assertEqual(Booking.objects.get().status, Booking.STATUS_PENDING)

    def test_host_sees_received_bookings(self):
        self.book(make_slot(self.host))
        host_api = self.client_for(self.host_user)
        self.assertEqual(host_api.get('/api/v1/bookings/').data['count'], 0)
        received = host_api.get('/api/v1/bookings/?role=host').data
        self.assertEqual(received['count'], 1)
        self.assertEqual(received['results'][0]['client']['id'], self.client_user.pk)
        self.assertNotIn('email', received['results'][0]['client'])

    def test_unpaid_booking_releases_slot_after_window(self):
        slot = make_slot(self.host)
        self.book(slot)
        Booking.objects.update(created_at=timezone.now() - timedelta(hours=1))
        self.api.get('/api/v1/bookings/')
        self.assertEqual(Booking.objects.get().status, Booking.STATUS_CANCELLED)
        slot.refresh_from_db()
        self.assertEqual(slot.status, Slot.STATUS_AVAILABLE)

    def test_strangers_cannot_cancel(self):
        r = self.book(make_slot(self.host))
        stranger = self.client_for(make_user('x@test.com'))
        self.assertEqual(stranger.post(f"/api/v1/bookings/{r.data['id']}/cancel/").status_code, 404)

    def test_host_cancellation_retires_the_slot(self):
        slot = make_slot(self.host)
        r = self.book(slot)
        self.client_for(self.host_user).post(f"/api/v1/bookings/{r.data['id']}/cancel/")
        slot.refresh_from_db()
        self.assertEqual(slot.status, Slot.STATUS_CANCELLED)


@override_settings(ALLOW_UNPAID_BOOKINGS=False, STRIPE_SECRET_KEY='sk_test_x')
class RefundPolicyTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.host_user = make_user('host@test.com')
        self.host = make_host(self.host_user)
        self.client_user = make_user('client@test.com')
        self.api = self.client_for(self.client_user)

    def paid_booking(self, starts_in):
        slot = make_slot(self.host, starts_in=starts_in, status=Slot.STATUS_BOOKED)
        booking = Booking.objects.create(
            client=self.client_user, host=self.host, slot=slot, amount=100,
            status=Booking.STATUS_CONFIRMED,
        )
        Payment.objects.create(booking=booking, stripe_payment_intent_id='pi_1', amount=100,
                               status=Payment.STATUS_CAPTURED)
        return booking

    @mock.patch('payments.services.stripe.Refund.create')
    def test_client_cancelling_early_is_refunded(self, refund):
        booking = self.paid_booking(timedelta(days=3))
        r = self.api.post(f'/api/v1/bookings/{booking.pk}/cancel/')
        self.assertEqual(r.status_code, 200, r.data)
        refund.assert_called_once_with(payment_intent='pi_1')
        self.assertEqual(Payment.objects.get().status, Payment.STATUS_REFUNDED)

    @mock.patch('payments.services.stripe.Refund.create')
    def test_client_cancelling_late_is_not_refunded(self, refund):
        booking = self.paid_booking(timedelta(hours=5))
        r = self.api.post(f'/api/v1/bookings/{booking.pk}/cancel/')
        self.assertEqual(r.status_code, 200)
        refund.assert_not_called()

    @mock.patch('payments.services.stripe.Refund.create')
    def test_host_cancelling_always_refunds(self, refund):
        booking = self.paid_booking(timedelta(hours=5))
        self.client_for(self.host_user).post(f'/api/v1/bookings/{booking.pk}/cancel/')
        refund.assert_called_once()

    @mock.patch('payments.services.stripe.Refund.create')
    def test_failed_refund_keeps_booking(self, refund):
        import stripe
        refund.side_effect = stripe.error.APIConnectionError('down')
        booking = self.paid_booking(timedelta(days=3))
        r = self.api.post(f'/api/v1/bookings/{booking.pk}/cancel/')
        self.assertEqual(r.status_code, 502)
        booking.refresh_from_db()
        self.assertEqual(booking.status, Booking.STATUS_CONFIRMED)


class ReviewTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.host_user = make_user('host@test.com')
        self.host = make_host(self.host_user)
        self.client_user = make_user('client@test.com')
        self.api = self.client_for(self.client_user)
        slot = make_slot(self.host, starts_in=-timedelta(hours=3), status=Slot.STATUS_BOOKED)
        self.booking = Booking.objects.create(
            client=self.client_user, host=self.host, slot=slot, amount=100,
            status=Booking.STATUS_CONFIRMED,
        )

    def test_review_after_meeting_updates_host_rating(self):
        r = self.api.post(f'/api/v1/bookings/{self.booking.pk}/review/', {'rating': 4, 'comment': 'Ótimo'})
        self.assertEqual(r.status_code, 201, r.data)
        self.host.refresh_from_db()
        self.assertEqual(float(self.host.rating), 4.0)
        self.assertEqual(self.host.review_count, 1)
        again = self.api.post(f'/api/v1/bookings/{self.booking.pk}/review/', {'rating': 5})
        self.assertEqual(again.status_code, 400)
        listed = self.api.get(f'/api/v1/profiles/{self.host.pk}/reviews/').data
        self.assertEqual([(x['rating'], x['comment']) for x in listed['results']], [(4, 'Ótimo')])

    def test_rating_must_be_one_to_five(self):
        r = self.api.post(f'/api/v1/bookings/{self.booking.pk}/review/', {'rating': 9})
        self.assertEqual(r.status_code, 400)
        self.assertFalse(Review.objects.exists())

    def test_cannot_review_future_meeting(self):
        slot = make_slot(self.host)
        future = Booking.objects.create(client=self.client_user, host=self.host, slot=slot,
                                        amount=100, status=Booking.STATUS_CONFIRMED)
        r = self.api.post(f'/api/v1/bookings/{future.pk}/review/', {'rating': 5})
        self.assertEqual(r.status_code, 400)


class TrainingSessionTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        from matches.models import MatchRequest
        self.a = make_user('a@test.com', gym=self.gym)
        self.b = make_user('b@test.com', gym=self.gym)
        MatchRequest.objects.create(sender=self.a, receiver=self.b, status=MatchRequest.STATUS_ACCEPTED)
        self.when = (timezone.now() + timedelta(days=1)).isoformat()

    def test_partners_schedule_and_confirm(self):
        r = self.client_for(self.a).post('/api/v1/sessions/', {'partner_id': self.b.pk, 'scheduled_at': self.when})
        self.assertEqual(r.status_code, 201, r.data)
        own = self.client_for(self.a).post(f"/api/v1/sessions/{r.data['id']}/confirm/")
        self.assertEqual(own.status_code, 404)  # only the invited partner confirms
        ok = self.client_for(self.b).post(f"/api/v1/sessions/{r.data['id']}/confirm/")
        self.assertEqual(ok.data['status'], 'confirmed')

    def test_only_matched_partners(self):
        stranger = make_user('c@test.com', gym=self.gym)
        r = self.client_for(self.a).post('/api/v1/sessions/', {'partner_id': stranger.pk, 'scheduled_at': self.when})
        self.assertEqual(r.status_code, 400)
