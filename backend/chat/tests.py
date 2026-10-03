from acompanha_testing import ApiTestCase, make_host, make_slot, make_user
from bookings.models import Booking
from matches.models import MatchRequest
from profiles.models import Slot


class ChatTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.ana = make_user('ana@test.com', display_name='Ana', gym=self.gym)
        self.bia = make_user('bia@test.com', display_name='Bia', gym=self.gym)

    def open_chat(self, user, other):
        return self.client_for(user).post('/api/v1/conversations/', {'user_id': other.pk})

    def test_strangers_cannot_start_a_chat(self):
        r = self.open_chat(self.ana, self.bia)
        self.assertEqual(r.status_code, 403)

    def test_matched_partners_chat_with_unread_counts(self):
        MatchRequest.objects.create(sender=self.ana, receiver=self.bia, status=MatchRequest.STATUS_ACCEPTED)
        conv = self.open_chat(self.ana, self.bia)
        self.assertEqual(conv.status_code, 200, conv.data)
        cid = conv.data['id']
        self.assertEqual(self.open_chat(self.bia, self.ana).data['id'], cid)  # same pair, same chat

        ana = self.client_for(self.ana)
        sent = ana.post(f'/api/v1/conversations/{cid}/messages/', {'text': '  Bora treinar amanhã? '})
        self.assertEqual(sent.status_code, 201)
        self.assertEqual(sent.data['text'], 'Bora treinar amanhã?')

        bia = self.client_for(self.bia)
        listing = bia.get('/api/v1/conversations/').data
        self.assertEqual(listing[0]['unread_count'], 1)
        self.assertEqual(listing[0]['other_user']['display_name'], 'Ana')
        self.assertNotIn('email', listing[0]['other_user'])
        self.assertEqual(bia.get('/api/v1/conversations/unread-count/').data['unread'], 1)

        messages = bia.get(f'/api/v1/conversations/{cid}/messages/').data
        self.assertEqual([m['text'] for m in messages], ['Bora treinar amanhã?'])
        self.assertEqual(bia.get('/api/v1/conversations/unread-count/').data['unread'], 0)

        ana.post(f'/api/v1/conversations/{cid}/messages/', {'text': 'Às 7h?'})
        newer = bia.get(f'/api/v1/conversations/{cid}/messages/', {'after': messages[-1]['id']}).data
        self.assertEqual([m['text'] for m in newer], ['Às 7h?'])

    def test_booking_lets_client_and_host_talk(self):
        host = make_host(self.bia)
        slot = make_slot(host, status=Slot.STATUS_BOOKED)
        Booking.objects.create(client=self.ana, host=host, slot=slot, amount=10, status=Booking.STATUS_CONFIRMED)
        self.assertEqual(self.open_chat(self.ana, self.bia).status_code, 200)

    def test_outsiders_cannot_read_or_post(self):
        MatchRequest.objects.create(sender=self.ana, receiver=self.bia, status=MatchRequest.STATUS_ACCEPTED)
        cid = self.open_chat(self.ana, self.bia).data['id']
        eve = self.client_for(make_user('eve@test.com'))
        self.assertEqual(eve.get(f'/api/v1/conversations/{cid}/messages/').status_code, 404)
        self.assertEqual(eve.post(f'/api/v1/conversations/{cid}/messages/', {'text': 'oi'}).status_code, 404)

    def test_empty_message_rejected(self):
        MatchRequest.objects.create(sender=self.ana, receiver=self.bia, status=MatchRequest.STATUS_ACCEPTED)
        cid = self.open_chat(self.ana, self.bia).data['id']
        r = self.client_for(self.ana).post(f'/api/v1/conversations/{cid}/messages/', {'text': '   '})
        self.assertEqual(r.status_code, 400)
