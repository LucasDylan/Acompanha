"""
Meeting categories a host can offer.

The database stores these stable slugs; the app owns the Portuguese labels.
Older rows (and older app builds) wrote Portuguese labels or workout names
instead, so anything coming in goes through `normalize_category` first.
"""
import unicodedata

CATEGORIES = ['coffee', 'networking', 'mentorship', 'language', 'travel', 'social', 'workout']

_LEGACY = {
    'cafe': 'coffee',
    'mentoria': 'mentorship',
    'pratica de idiomas': 'language',
    'idiomas': 'language',
    'acompanhamento de viagem': 'travel',
    'viagem': 'travel',
    'social casual': 'social',
    'treino': 'workout',
    'musculacao': 'workout',
    'cardio': 'workout',
    'crossfit': 'workout',
    'funcional': 'workout',
    'pilates': 'workout',
    'calistenia': 'workout',
    'natacao': 'workout',
    'personal trainer': 'workout',
}


def _plain(value):
    value = unicodedata.normalize('NFKD', str(value)).encode('ascii', 'ignore').decode()
    return value.strip().lower()


def normalize_category(value):
    """Slug for a category given as a slug, a Portuguese label or a workout name.
    Returns None for anything unrecognized."""
    plain = _plain(value)
    if plain in CATEGORIES:
        return plain
    return _LEGACY.get(plain)


def normalize_categories(values):
    """De-duplicated slugs, in the order given, dropping unknown entries."""
    out = []
    for value in values or []:
        slug = normalize_category(value)
        if slug and slug not in out:
            out.append(slug)
    return out
