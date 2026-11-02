"""Write real API responses to ../test/fixtures/api/ for the app's contract test.

Everything runs inside a transaction that is rolled back (and uploads go to a
temp folder), so the database is left untouched. Re-run after changing a
serializer, then `flutter test test/core/api_contract_test.dart`:

    python manage.py shell < tools/export_api_fixtures.py
"""
import json
import shutil
import tempfile
from datetime import timedelta
from pathlib import Path

from django.conf import settings
from django.db import transaction
from django.test import override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import User
from bookings.models import Booking, Review, TrainingSession
from gyms.models import Gym
from matches.models import MatchRequest
from profiles.models import HostProfile, Slot

OUT = Path(settings.BASE_DIR).parent / 'test' / 'fixtures' / 'api'


class _Rollback(Exception):
    pass


def save(name, response):
    assert response.status_code < 400, (name, response.status_code, response.data)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f'{name}.json').write_text(
        json.dumps(response.json(), ensure_ascii=False, indent=2) + '\n', encoding='utf-8',
    )
    print('wrote', name)


def client_for(user):
    c = APIClient()
    c.force_authenticate(user)
    return c


media = tempfile.mkdtemp()
try:
    with override_settings(MEDIA_ROOT=media, ALLOW_UNPAID_BOOKINGS=True), transaction.atomic():
        gym = Gym.objects.create(name='Academia Contrato', city='São Paulo, SP')
        ana = User.objects.create_user(username='ana@contract.test', email='ana@contract.test',
                                       password='x', display_name='Ana', gym=gym,
                                       workout_types=['Musculação'], available_days=['Seg', 'Qua'],
                                       fitness_level='intermediate', age=30, bio='Treino cedo.')
        bia = User.objects.create_user(username='bia@contract.test', email='bia@contract.test',
                                       password='x', display_name='Bia', gym=gym)
        host = HostProfile.objects.create(user=bia, display_name='Bia Host', bio='Mentoria.',
                                          categories=['mentorship', 'coffee'], price_per_hour=80,
                                          location='São Paulo, SP', rating=4.5, review_count=1)
        now = timezone.now()
        future = Slot.objects.create(host=host, start_at=now + timedelta(days=2),
                                     end_at=now + timedelta(days=2, minutes=90))
        past = Slot.objects.create(host=host, start_at=now - timedelta(days=2),
                                   end_at=now - timedelta(days=2, minutes=-60), status=Slot.STATUS_BOOKED)
        done = Booking.objects.create(client=ana, host=host, slot=past, amount=80,
                                      status=Booking.STATUS_COMPLETED)
        Review.objects.create(booking=done, rating=5, comment='Ótima conversa')
        MatchRequest.objects.create(sender=bia, receiver=ana, status=MatchRequest.STATUS_ACCEPTED)
        TrainingSession.objects.create(initiator=ana, partner=bia, gym=gym,
                                       scheduled_at=now + timedelta(days=1), workout_type='Cardio')

        a, b = client_for(ana), client_for(bia)
        save('me', a.get('/api/v1/auth/me/'))
        save('hosts_page', a.get('/api/v1/profiles/hosts/'))
        save('host_detail', a.get(f'/api/v1/profiles/{host.pk}/'))
        save('host_reviews', a.get(f'/api/v1/profiles/{host.pk}/reviews/'))
        save('host_slots', a.get(f'/api/v1/profiles/{host.pk}/slots/'))
        save('booking_created', a.post('/api/v1/bookings/', {'slot_id': future.pk, 'host_id': host.pk},
                                       format='json'))
        save('my_bookings', a.get('/api/v1/bookings/'))
        save('received_bookings', b.get('/api/v1/bookings/?role=host'))
        save('payment_config', a.get('/api/v1/payments/config/'))
        save('gym_members', b.get('/api/v1/gym-members/'))
        save('my_matches', a.get('/api/v1/matches/'))
        save('sessions', a.get('/api/v1/sessions/'))
        conv = a.post('/api/v1/conversations/', {'user_id': bia.pk}, format='json')
        save('conversation_opened', conv)
        save('message_sent', a.post(f"/api/v1/conversations/{conv.json()['id']}/messages/",
                                    {'text': 'Oi, Bia!'}, format='json'))
        save('conversations', b.get('/api/v1/conversations/'))
        save('messages', b.get(f"/api/v1/conversations/{conv.json()['id']}/messages/"))
        save('unread_count', a.get('/api/v1/conversations/unread-count/'))
        # A third person, so blocking doesn't hide Bia from the responses above.
        cid = User.objects.create_user(username='cid@contract.test', email='cid@contract.test',
                                       password='x', display_name='Cid')
        save('report_created', a.post('/api/v1/reports/', {'user_id': cid.pk, 'reason': 'spam', 'block': True},
                                      format='json'))
        save('blocks', a.get('/api/v1/blocks/'))
        raise _Rollback()
except _Rollback:
    print('rolled back')
finally:
    shutil.rmtree(media, ignore_errors=True)
