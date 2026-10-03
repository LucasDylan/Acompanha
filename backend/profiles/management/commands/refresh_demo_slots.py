"""Give the seeded demo hosts fresh, bookable slots in the coming weeks.

Seeded slots go stale as time passes (every one of them ends up in the past),
which leaves Discovery with nothing to book. Run this whenever that happens.
"""
from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from profiles.demo import SEED_PREFIX, future_slots
from profiles.models import HostProfile, Slot


class Command(BaseCommand):
    help = 'Replace stale open slots of seeded demo hosts with new ones in the next weeks.'

    def handle(self, *args, **options):
        hosts = HostProfile.objects.filter(user__username__startswith=SEED_PREFIX)
        with transaction.atomic():
            stale, _ = Slot.objects.filter(
                host__in=hosts, status=Slot.STATUS_AVAILABLE, start_at__lt=timezone.now(),
            ).delete()
            new = []
            for host in hosts:
                new.extend(future_slots(host))
            Slot.objects.bulk_create(new, batch_size=1000)
        self.stdout.write(self.style.SUCCESS(
            f'Removed {stale} past open slots; created {len(new)} new ones for {hosts.count()} demo hosts.'
        ))
