from datetime import timedelta

from django.utils import timezone

from acompanha_testing import ApiTestCase, image_file, make_host, make_slot, make_user
from profiles.categories import normalize_categories
from profiles.models import ProfilePhoto, Slot


class CategoryTests(ApiTestCase):
    def test_legacy_labels_become_slugs(self):
        self.assertEqual(
            normalize_categories(['Café', 'Prática de idiomas', 'Musculação', 'cardio', '???', 'coffee']),
            ['coffee', 'language', 'workout'],
        )

    def test_discovery_filters_by_slug_or_label(self):
        viewer = self.client_for(make_user('me@test.com'))
        make_host(make_user('a@test.com'), categories=['coffee'])
        make_host(make_user('b@test.com'), categories=['travel'])
        for value in ('coffee', 'Café'):
            r = viewer.get('/api/v1/profiles/hosts/', {'categories': value})
            self.assertEqual(r.data['count'], 1, value)

    def test_upsert_requires_known_category_and_price(self):
        api = self.client_for(make_user('h@test.com'))
        r = api.post('/api/v1/profiles/me/', {'display_name': 'H', 'categories': ['xyz']}, format='json')
        self.assertEqual(r.status_code, 400)
        r = api.post('/api/v1/profiles/me/', {'display_name': 'H', 'categories': ['Mentoria'],
                                              'price_per_hour': 50}, format='json')
        self.assertEqual(r.status_code, 200, r.data)
        self.assertEqual(r.data['categories'], ['mentorship'])


class DiscoveryTests(ApiTestCase):
    def test_hides_own_and_inactive_listings(self):
        me = make_user('me@test.com')
        make_host(me)
        make_host(make_user('paused@test.com'), is_active=False)
        visible = make_host(make_user('ok@test.com'))
        r = self.client_for(me).get('/api/v1/profiles/hosts/')
        self.assertEqual([h['id'] for h in r.data['results']], [str(visible.pk)])


class PhotoOwnershipTests(ApiTestCase):
    def test_only_owner_can_add_or_remove_photos(self):
        owner = make_user('owner@test.com')
        host = make_host(owner)
        intruder = self.client_for(make_user('intruder@test.com'))

        r = intruder.post(f'/api/v1/profiles/{host.pk}/photos/', {'image': image_file()}, format='multipart')
        self.assertEqual(r.status_code, 403)
        self.assertFalse(ProfilePhoto.objects.exists())

        r = self.client_for(owner).post(f'/api/v1/profiles/{host.pk}/photos/', {'image': image_file()},
                                        format='multipart')
        self.assertEqual(r.status_code, 201, r.data)
        url = r.data['image']
        self.assertEqual(intruder.delete(f'/api/v1/profiles/{host.pk}/photos/', {'url': url}).status_code, 403)
        self.assertEqual(ProfilePhoto.objects.count(), 1)

    def test_rejects_non_images(self):
        from django.core.files.uploadedfile import SimpleUploadedFile
        owner = make_user('owner@test.com')
        host = make_host(owner)
        fake = SimpleUploadedFile('x.png', b'not an image', content_type='image/png')
        r = self.client_for(owner).post(f'/api/v1/profiles/{host.pk}/photos/', {'image': fake}, format='multipart')
        self.assertEqual(r.status_code, 400)


class SlotTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.owner = make_user('owner@test.com')
        self.host = make_host(self.owner)
        self.url = f'/api/v1/profiles/{self.host.pk}/slots/'

    def test_visitors_only_see_future_open_slots(self):
        make_slot(self.host, starts_in=-timedelta(days=1))
        make_slot(self.host, starts_in=timedelta(days=2), status=Slot.STATUS_BOOKED)
        open_slot = make_slot(self.host, starts_in=timedelta(days=3))
        r = self.client_for(make_user('v@test.com')).get(self.url)
        self.assertEqual([s['id'] for s in r.data], [str(open_slot.pk)])
        owner_view = self.client_for(self.owner).get(self.url)
        self.assertEqual(len(owner_view.data), 2)  # sees their booked slot too

    def test_create_rules(self):
        api = self.client_for(self.owner)
        start = timezone.now() + timedelta(days=1)

        def post(s, e):
            return api.post(self.url, {'start_at': s.isoformat(), 'end_at': e.isoformat()})

        self.assertEqual(post(start, start + timedelta(hours=1)).status_code, 201)
        self.assertEqual(post(start + timedelta(minutes=30), start + timedelta(hours=2)).status_code, 400)  # overlap
        past = timezone.now() - timedelta(hours=1)
        self.assertEqual(post(past, past + timedelta(hours=1)).status_code, 400)
        later = start + timedelta(days=1)
        self.assertEqual(post(later, later + timedelta(minutes=10)).status_code, 400)  # too short
        naive = api.post(self.url, {'start_at': '2030-01-01T10:00:00', 'end_at': '2030-01-01T11:00:00'})
        self.assertEqual(naive.status_code, 400)
        other = self.client_for(make_user('x@test.com'))
        self.assertEqual(other.post(self.url, {'start_at': later.isoformat(),
                                               'end_at': (later + timedelta(hours=1)).isoformat()}).status_code, 403)
