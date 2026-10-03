"""Rewrite stored host categories as the stable slugs the API now uses
('Café' -> 'coffee', 'Musculação' -> 'workout', ...)."""
from django.db import migrations

from profiles.categories import normalize_categories


def forwards(apps, schema_editor):
    HostProfile = apps.get_model('profiles', 'HostProfile')
    for host in HostProfile.objects.all().only('id', 'categories'):
        normalized = normalize_categories(host.categories)
        if normalized != host.categories:
            host.categories = normalized
            host.save(update_fields=['categories'])


class Migration(migrations.Migration):

    dependencies = [
        ('profiles', '0003_hostprofile_is_trainer'),
    ]

    operations = [
        migrations.RunPython(forwards, migrations.RunPython.noop),
    ]
