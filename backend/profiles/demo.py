"""Shared bits for the demo-data management commands."""
import random
from datetime import datetime, time, timedelta
from zoneinfo import ZoneInfo

from django.utils import timezone

from .models import Slot

SEED_PREFIX = 'seed_host_'
# Local (Brasília) hours, so a "9h" slot shows as 9h in the app.
SLOT_HOURS = [9, 10, 11, 14, 15, 16, 17, 18, 19]
LOCAL_TZ = ZoneInfo('America/Sao_Paulo')


def future_slots(host, days=21, per_host=(3, 8)):
    """Unsaved one-hour slots for `host` spread over the next `days` days."""
    today = timezone.now().astimezone(LOCAL_TZ).date()
    taken = set()
    slots = []
    for _ in range(random.randint(*per_host)):
        day = today + timedelta(days=random.randint(1, days))
        hour = random.choice(SLOT_HOURS)
        if (day, hour) in taken:
            continue
        taken.add((day, hour))
        start = datetime.combine(day, time(hour), tzinfo=LOCAL_TZ)
        slots.append(Slot(host=host, start_at=start, end_at=start + timedelta(hours=1)))
    return slots
