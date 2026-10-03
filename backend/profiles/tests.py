import io
from datetime import timedelta
from email.message import Message
from pathlib import Path
from unittest import mock
from urllib.error import URLError

from django.conf import settings
from django.utils import timezone

from acompanha_testing import ApiTestCase, image_file, make_host, make_slot, make_user
from profiles import demo_photos
from profiles.categories import CATEGORIES, normalize_categories
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


class FakeImageResponse(io.BytesIO):
    def __init__(self):
        super().__init__(b'\xff\xd8 not really a jpeg')
        self.headers = Message()
        self.headers['Content-Type'] = 'image/jpeg'


class DemoPhotoTests(ApiTestCase):
    photos = demo_photos.DemoPhotos(
        female=['demo/portraits/f1.jpg', 'demo/portraits/f2.jpg'],
        male=['demo/portraits/m1.jpg'],
        scenes={
            'coffee': ['demo/scenes/coffee/c1.jpg', 'demo/scenes/coffee/c2.jpg'],
            'travel': ['demo/scenes/travel/t1.jpg'],
        },
    )

    def test_faces_match_the_name_and_galleries_the_categories(self):
        ana = make_user('seed_host_0', display_name='Ana Silva')
        bruno = make_user('seed_host_1', display_name='Bruno Costa', avatar_url='https://images.unsplash.com/x')
        host = make_host(bruno, categories=['travel', 'coffee'])
        real = make_user('real@test.com', display_name='Ana Real', avatar_url='https://example.com/me.jpg')

        for _ in range(2):  # re-running must not pile up photos
            self.assertEqual(demo_photos.assign_photos(self.photos), (2, 1))

        ana.refresh_from_db()
        bruno.refresh_from_db()
        real.refresh_from_db()
        self.assertIn(ana.avatar.name, self.photos.female)
        self.assertEqual(bruno.avatar.name, 'demo/portraits/m1.jpg')
        self.assertEqual(bruno.avatar_url, '')
        self.assertFalse(real.avatar)
        self.assertEqual(real.avatar_url, 'https://example.com/me.jpg')

        gallery = list(host.photos.values_list('photo', flat=True))
        self.assertEqual(len(gallery), 2)
        self.assertEqual(gallery[0], 'demo/scenes/travel/t1.jpg')
        self.assertIn(gallery[1], self.photos.scenes['coffee'])

        r = self.client_for(real).get(f'/api/v1/profiles/{host.pk}/')
        self.assertTrue(r.data['avatar_url'].endswith('/media/demo/portraits/m1.jpg'), r.data['avatar_url'])
        self.assertEqual(len(r.data['photos']), 2)

    def test_download_keeps_what_it_got_when_offline(self):
        def urlopen(url, timeout):
            if 'crop=faces' not in url:
                raise URLError('offline')
            return FakeImageResponse()

        with mock.patch('profiles.demo_photos.urlopen', urlopen):
            photos = demo_photos.download_photos()

        self.assertEqual(len(photos.female), len(demo_photos.FEMALE_PORTRAITS))
        self.assertEqual(len(photos.male), len(demo_photos.MALE_PORTRAITS))
        self.assertEqual(photos.scenes, {})
        self.assertEqual(photos.missing, sum(len(ids) for ids in demo_photos.SCENES.values()))
        self.assertTrue((Path(settings.MEDIA_ROOT) / photos.female[0]).exists())

    def test_photo_lists_have_no_duplicates_and_cover_every_category(self):
        portraits = demo_photos.FEMALE_PORTRAITS + demo_photos.MALE_PORTRAITS
        self.assertEqual(len(portraits), len(set(portraits)))
        self.assertEqual(set(demo_photos.SCENES), set(CATEGORIES))
