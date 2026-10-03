from django.core import mail

from acompanha_testing import ApiTestCase, image_file, make_host, make_slot, make_user
from bookings.models import Booking
from matches.models import MatchRequest
from profiles.models import Slot

from .models import PasswordResetCode, User


class RegisterLoginTests(ApiTestCase):
    def test_register_normalizes_email_and_rejects_duplicates(self):
        r = self.client.post('/api/v1/auth/register/',
                             {'email': ' Ana@Test.com ', 'password': 'Senha-Forte-123', 'display_name': 'Ana'})
        self.assertEqual(r.status_code, 201, r.data)
        self.assertEqual(r.data['user']['email'], 'ana@test.com')
        dup = self.client.post('/api/v1/auth/register/', {'email': 'ANA@test.com', 'password': 'Outra-Senha-456'})
        self.assertEqual(dup.status_code, 400)
        self.assertIn('email', dup.data)

    def test_register_rejects_weak_password(self):
        r = self.client.post('/api/v1/auth/register/', {'email': 'b@test.com', 'password': '123456'})
        self.assertEqual(r.status_code, 400)
        self.assertIn('password', r.data)

    def test_login_is_case_insensitive_and_hides_which_part_failed(self):
        make_user('carla@test.com')
        ok = self.client.post('/api/v1/auth/login/', {'email': 'CARLA@test.com', 'password': 'Senha-Forte-123'})
        self.assertEqual(ok.status_code, 200)
        bad = self.client.post('/api/v1/auth/login/', {'email': 'carla@test.com', 'password': 'errada'})
        self.assertEqual(bad.status_code, 401)
        self.assertEqual(bad.data['detail'], 'E-mail ou senha incorretos.')

    def test_login_is_throttled(self):
        for _ in range(20):
            self.client.post('/api/v1/auth/login/', {'email': 'x@test.com', 'password': 'y'})
        r = self.client.post('/api/v1/auth/login/', {'email': 'x@test.com', 'password': 'y'})
        self.assertEqual(r.status_code, 429)


class PasswordResetTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.user = make_user('reset@test.com')

    def request_code(self):
        self.client.post('/api/v1/auth/password-reset/', {'email': 'reset@test.com'})
        return PasswordResetCode.objects.filter(user=self.user, used=False).latest('created_at').code

    def confirm(self, code, password='Nova-Senha-789'):
        return self.client.post('/api/v1/auth/password-reset/confirm/',
                                {'email': 'reset@test.com', 'code': code, 'new_password': password})

    def test_full_flow(self):
        code = self.request_code()
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(self.confirm(code).status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('Nova-Senha-789'))

    def test_code_dies_after_five_wrong_guesses(self):
        code = self.request_code()
        wrong = '000000' if code != '000000' else '111111'
        for _ in range(PasswordResetCode.MAX_FAILED_ATTEMPTS):
            self.assertEqual(self.confirm(wrong).status_code, 400)
        self.assertEqual(self.confirm(code).status_code, 400)  # even the right one is dead now

    def test_new_code_invalidates_old_one(self):
        old = self.request_code()
        new = self.request_code()
        if old != new:
            self.assertEqual(self.confirm(old).status_code, 400)
        self.assertEqual(self.confirm(new).status_code, 200)

    def test_weak_new_password_rejected(self):
        code = self.request_code()
        self.assertEqual(self.confirm(code, password='123').status_code, 400)


class ProfileTests(ApiTestCase):
    def test_update_fitness_profile(self):
        user = make_user('me@test.com')
        api = self.client_for(user)
        r = api.patch('/api/v1/auth/me/', {
            'display_name': 'Novo Nome', 'fitness_level': 'advanced',
            'workout_types': ['Musculação', 'Corrida'], 'available_days': ['Sex', 'Seg'],
            'age': 30, 'gym_id': self.gym.pk,
        }, format='json')
        self.assertEqual(r.status_code, 200, r.data)
        self.assertEqual(r.data['available_days'], ['Seg', 'Sex'])
        self.assertEqual(r.data['gym']['id'], self.gym.pk)
        bad = api.patch('/api/v1/auth/me/', {'available_days': ['Funday']}, format='json')
        self.assertEqual(bad.status_code, 400)

    def test_avatar_upload(self):
        user = make_user('me@test.com')
        r = self.client_for(user).post('/api/v1/auth/me/avatar/', {'image': image_file()}, format='multipart')
        self.assertEqual(r.status_code, 200, r.data)
        self.assertTrue(r.data['avatar_url'].startswith('http'))


class GymMembersTests(ApiTestCase):
    def test_lists_gym_mates_without_emails_and_with_match_status(self):
        me = make_user('me@test.com', gym=self.gym)
        sent_to = make_user('sent@test.com', gym=self.gym)
        from_them = make_user('them@test.com', gym=self.gym)
        make_user('elsewhere@test.com')
        MatchRequest.objects.create(sender=me, receiver=sent_to)
        MatchRequest.objects.create(sender=from_them, receiver=me)

        r = self.client_for(me).get('/api/v1/gym-members/')
        members = {m['id']: m for m in r.data['results']}
        self.assertEqual(set(members), {sent_to.pk, from_them.pk})
        self.assertNotIn('email', members[sent_to.pk])
        self.assertEqual(members[sent_to.pk]['match_status'], 'sent')
        self.assertEqual(members[from_them.pk]['match_status'], 'received')

    def test_match_requests_need_same_gym(self):
        me = make_user('me@test.com', gym=self.gym)
        outsider = make_user('out@test.com')
        r = self.client_for(me).post('/api/v1/matches/request/', {'receiver_id': outsider.pk})
        self.assertEqual(r.status_code, 400)


class DeleteAccountTests(ApiTestCase):
    def test_delete_account_anonymizes_and_blocks_login(self):
        user = make_user('bye@test.com', display_name='Tchau')
        host = make_host(user)
        open_slot = make_slot(host)
        client = make_user('client@test.com')
        booked = make_slot(host, status=Slot.STATUS_BOOKED)
        booking = Booking.objects.create(client=client, host=host, slot=booked, amount=100,
                                         status=Booking.STATUS_CONFIRMED)

        r = self.client_for(user).delete('/api/v1/auth/me/')
        self.assertEqual(r.status_code, 204)

        user.refresh_from_db()
        self.assertFalse(user.is_active)
        self.assertNotEqual(user.email, 'bye@test.com')
        self.assertEqual(user.display_name, 'Conta excluída')
        host.refresh_from_db()
        self.assertFalse(host.is_active)
        self.assertFalse(Slot.objects.filter(pk=open_slot.pk).exists())
        booking.refresh_from_db()
        self.assertEqual(booking.status, Booking.STATUS_CANCELLED)

        login = self.client.post('/api/v1/auth/login/', {'email': 'bye@test.com', 'password': 'Senha-Forte-123'})
        self.assertEqual(login.status_code, 401)
        self.assertFalse(User.objects.filter(email='bye@test.com').exists())

    def test_deleted_users_refresh_tokens_stop_working(self):
        user = make_user('bye@test.com')
        tokens = self.client.post('/api/v1/auth/login/', {'email': 'bye@test.com', 'password': 'Senha-Forte-123'}).data
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
        self.client.delete('/api/v1/auth/me/')
        self.client.credentials()
        r = self.client.post('/api/v1/auth/token/refresh/', {'refresh': tokens['refresh']})
        self.assertEqual(r.status_code, 401)
