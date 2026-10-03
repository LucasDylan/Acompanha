"""Factories shared by the apps' test suites."""
import io
import shutil
import tempfile
from datetime import timedelta
from decimal import Decimal

from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django.utils import timezone
from PIL import Image
from rest_framework.test import APIClient, APITestCase

from accounts.models import User
from gyms.models import Gym
from profiles.models import HostProfile, Slot


def make_user(email, gym=None, **extra):
    return User.objects.create_user(
        username=email, email=email, password='Senha-Forte-123', gym=gym, **extra,
    )


def make_host(user, price='100.00', categories=('coffee',), **extra):
    return HostProfile.objects.create(
        user=user,
        display_name=user.display_name or user.email,
        price_per_hour=Decimal(price),
        categories=list(categories),
        **extra,
    )


def make_slot(host, starts_in=timedelta(days=3), hours=1, status=Slot.STATUS_AVAILABLE):
    start = timezone.now() + starts_in
    return Slot.objects.create(host=host, start_at=start, end_at=start + timedelta(hours=hours), status=status)


def image_file(name='photo.png'):
    buf = io.BytesIO()
    Image.new('RGB', (4, 4), 'red').save(buf, 'PNG')
    return SimpleUploadedFile(name, buf.getvalue(), content_type='image/png')


class ApiTestCase(APITestCase):
    def setUp(self):
        super().setUp()
        cache.clear()  # throttling counters live in the cache
        # Uploads go to a throwaway folder, never the real media/ directory.
        media_root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, media_root, ignore_errors=True)
        media = override_settings(MEDIA_ROOT=media_root)
        media.enable()
        self.addCleanup(media.disable)
        self.gym = Gym.objects.create(name='Academia Teste', city='São Paulo')

    def client_for(self, user):
        client = APIClient()
        client.force_authenticate(user)
        return client
