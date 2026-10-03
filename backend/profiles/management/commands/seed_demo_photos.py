"""Give the seed_hosts demo accounts stock photos: a portrait and a host gallery."""
from django.core.management.base import BaseCommand

from profiles.demo_photos import assign_photos, download_photos


class Command(BaseCommand):
    help = 'Download the demo photos (first run only) and give them to the seed_hosts accounts.'

    def handle(self, *args, **options):
        self.stdout.write('Fetching demo photos (only the missing ones are downloaded)...')
        photos = download_photos()
        if photos.missing:
            self.stderr.write(self.style.WARNING(
                f'{photos.missing} photos could not be downloaded (offline?) — using the rest.'
            ))
        if not (photos.female or photos.male):
            self.stderr.write(self.style.WARNING('No demo photos available; accounts keep their initials.'))
            return
        accounts, galleries = assign_photos(photos)
        self.stdout.write(self.style.SUCCESS(
            f'{accounts} demo accounts got a portrait and {galleries} hosts a gallery '
            f'(files in MEDIA_ROOT/demo/).'
        ))
