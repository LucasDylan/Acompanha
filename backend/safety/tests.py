from datetime import timedelta

from django.core import mail
from django.test import override_settings
from django.utils import timezone

from acompanha_testing import ApiTestCase, make_host, make_slot, make_user
from bookings.models import TrainingSession
from chat.models import Conversation, Message
from matches.models import MatchRequest
from safety.models import Block, Report


class BlockTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.ana = make_user('ana@test.com', display_name='Ana', gym=self.gym)
        self.bia = make_user('bia@test.com', display_name='Bia', gym=self.gym)
        self.bia_host = make_host(self.bia)
        self.slot = make_slot(self.bia_host)
        self.api = self.client_for(self.ana)

    def block(self, client, user):
        return client.post('/api/v1/blocks/', {'user_id': user.pk})

    def test_blocked_people_disappear_for_each_other(self):
        conv = Conversation.between(self.ana, self.bia)
        Message.objects.create(conversation=conv, sender=self.bia, text='Oi')
        conv.last_message_at = timezone.now()
        conv.save()

        # Bia blocks Ana: it works both ways.
        r = self.block(self.client_for(self.bia), self.ana)
        self.assertEqual(r.status_code, 201, r.data)

        self.assertEqual(self.api.get('/api/v1/profiles/hosts/').data['count'], 0)
        self.assertEqual(self.api.get(f'/api/v1/profiles/{self.bia_host.pk}/').status_code, 404)
        self.assertEqual(self.api.get(f'/api/v1/profiles/{self.bia_host.pk}/slots/').data, [])
        self.assertEqual(self.api.get('/api/v1/gym-members/').data['count'], 0)
        self.assertEqual(self.api.get('/api/v1/conversations/').data, [])
        self.assertEqual(self.api.get('/api/v1/conversations/unread-count/').data['unread'], 0)

        self.assertEqual(self.api.post('/api/v1/conversations/', {'user_id': self.bia.pk}).status_code, 403)
        sent = self.api.post(f'/api/v1/conversations/{conv.pk}/messages/', {'text': 'Oi?'})
        self.assertEqual(sent.status_code, 404)
        booking = self.api.post('/api/v1/bookings/', {'slot_id': self.slot.pk, 'host_id': self.bia_host.pk})
        self.assertEqual(booking.status_code, 403)
        partner = self.api.post('/api/v1/matches/request/', {'receiver_id': self.bia.pk})
        self.assertEqual(partner.status_code, 403)

    def test_blocking_ends_the_partnership_and_planned_training(self):
        MatchRequest.objects.create(sender=self.ana, receiver=self.bia, status=MatchRequest.STATUS_ACCEPTED)
        session = TrainingSession.objects.create(
            initiator=self.ana, partner=self.bia, gym=self.gym,
            scheduled_at=timezone.now() + timedelta(days=1),
        )
        self.block(self.api, self.bia)
        self.assertFalse(MatchRequest.are_matched(self.ana, self.bia))
        session.refresh_from_db()
        self.assertEqual(session.status, TrainingSession.STATUS_CANCELLED)

    def test_list_and_unblock(self):
        self.block(self.api, self.bia)
        self.block(self.api, self.bia)  # twice is fine
        listed = self.api.get('/api/v1/blocks/').data
        self.assertEqual([b['display_name'] for b in listed], ['Bia'])

        self.assertEqual(self.api.delete(f'/api/v1/blocks/{self.bia.pk}/').status_code, 204)
        self.assertEqual(self.api.get('/api/v1/blocks/').data, [])
        self.assertEqual(self.api.get('/api/v1/profiles/hosts/').data['count'], 1)

    def test_cannot_block_yourself(self):
        self.assertEqual(self.block(self.api, self.ana).status_code, 400)


class ReportTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.ana = make_user('ana@test.com', display_name='Ana', gym=self.gym)
        self.bia = make_user('bia@test.com', display_name='Bia', gym=self.gym)
        self.api = self.client_for(self.ana)

    @override_settings(MODERATION_EMAIL='moderacao@test.com')
    def test_report_from_a_chat_blocks_and_alerts_moderators(self):
        conv = Conversation.between(self.ana, self.bia)
        r = self.api.post('/api/v1/reports/', {
            'user_id': self.bia.pk,
            'reason': 'harassment',
            'details': '  Mensagens ofensivas.  ',
            'conversation_id': conv.pk,
            'block': True,
        }, format='json')
        self.assertEqual(r.status_code, 201, r.data)

        report = Report.objects.get()
        self.assertEqual((report.reported, report.reporter, report.conversation), (self.bia, self.ana, conv))
        self.assertEqual(report.details, 'Mensagens ofensivas.')
        self.assertTrue(Block.objects.filter(blocker=self.ana, blocked=self.bia).exists())
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn('Assédio ou ofensa', mail.outbox[0].subject)

    def test_rejects_bad_reports(self):
        stranger_chat = Conversation.between(self.bia, make_user('cid@test.com'))
        cases = [
            {'user_id': self.ana.pk, 'reason': 'spam'},  # yourself
            {'user_id': self.bia.pk, 'reason': 'nope'},  # unknown reason
            {'user_id': self.bia.pk, 'reason': 'spam', 'conversation_id': stranger_chat.pk},
        ]
        for body in cases:
            self.assertEqual(self.api.post('/api/v1/reports/', body, format='json').status_code, 400, body)
        self.assertFalse(Report.objects.exists())
