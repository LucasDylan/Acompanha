"""Seed mock HostProfile records (with slots) for discovery performance testing."""
import random

from django.contrib.auth.hashers import make_password
from django.core.management.base import BaseCommand
from django.db import transaction

from accounts.models import User
from profiles.categories import CATEGORIES
from profiles.demo import SEED_PREFIX, future_slots
from profiles.models import HostProfile, Slot

FIRST_NAMES = [
    'Ana', 'Bruno', 'Carla', 'Diego', 'Elisa', 'Fábio', 'Gabriela', 'Hugo',
    'Isabela', 'João', 'Karina', 'Lucas', 'Mariana', 'Nathan', 'Olívia',
    'Pedro', 'Rafaela', 'Samuel', 'Tatiana', 'Vitor', 'Yasmin', 'André',
]
LAST_NAMES = [
    'Silva', 'Souza', 'Oliveira', 'Santos', 'Pereira', 'Costa', 'Almeida',
    'Ferreira', 'Rodrigues', 'Carvalho', 'Gomes', 'Martins', 'Araújo', 'Lima',
    'Barbosa', 'Ribeiro', 'Cardoso', 'Teixeira', 'Moreira', 'Nascimento',
]
CATEGORY_LABELS = {
    'coffee': 'café e boa conversa',
    'networking': 'networking',
    'mentorship': 'mentoria de carreira',
    'language': 'prática de idiomas',
    'travel': 'roteiros pela cidade',
    'social': 'eventos e vida social',
    'workout': 'treino acompanhado',
}
BIO_TEMPLATES = [
    'Adoro {cat}. Bora marcar?',
    'Anos de experiência com {cat} — feedback sincero e prático.',
    'Disponível para {cat}, presencial ou remoto.',
    'Especialista em {cat}. Primeira conversa sem compromisso.',
]
CITIES = [
    'São Paulo, SP', 'Rio de Janeiro, RJ', 'Belo Horizonte, MG', 'Curitiba, PR',
    'Porto Alegre, RS', 'Salvador, BA', 'Recife, PE', 'Brasília, DF',
    'Florianópolis, SC', 'Fortaleza, CE', 'Campinas, SP', 'Goiânia, GO',
]
PRICES = [40, 50, 60, 70, 80, 90, 100, 120, 150, 180, 200, 250]


class Command(BaseCommand):
    help = 'Create N mock host profiles (+ slots) for discovery performance testing.'

    def add_arguments(self, parser):
        parser.add_argument('--count', type=int, default=500, help='Number of hosts to create.')
        parser.add_argument('--clear', action='store_true', help='Delete previously seeded hosts first.')

    def handle(self, *args, **options):
        count = options['count']

        if options['clear']:
            deleted, _ = User.objects.filter(username__startswith=SEED_PREFIX).delete()
            self.stdout.write(self.style.WARNING(f'Removed {deleted} previously seeded rows.'))

        start_index = User.objects.filter(username__startswith=SEED_PREFIX).count()
        unusable_password = make_password(None)

        with transaction.atomic():
            users = [
                User(
                    username=f'{SEED_PREFIX}{i}',
                    email=f'{SEED_PREFIX}{i}@meetly.test',
                    password=unusable_password,
                    display_name=f'{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}',
                    is_active=True,
                )
                for i in range(start_index, start_index + count)
            ]
            User.objects.bulk_create(users, batch_size=500)

            created_users = list(User.objects.filter(username__startswith=SEED_PREFIX).order_by('id')[start_index:start_index + count])

            hosts = []
            for user in created_users:
                cats = random.sample(CATEGORIES, k=random.randint(1, 3))
                hosts.append(HostProfile(
                    user=user,
                    display_name=user.display_name,
                    bio=random.choice(BIO_TEMPLATES).format(cat=CATEGORY_LABELS[cats[0]]),
                    categories=cats,
                    price_per_hour=random.choice(PRICES),
                    currency='BRL',
                    location=random.choice(CITIES),
                    rating=round(random.uniform(3.5, 5.0), 2),
                    review_count=random.randint(0, 300),
                    is_active=True,
                ))
            HostProfile.objects.bulk_create(hosts, batch_size=500)

            created_hosts = HostProfile.objects.filter(user__in=created_users)

            slots = []
            for host in created_hosts:
                slots.extend(future_slots(host))
            Slot.objects.bulk_create(slots, batch_size=1000)

        self.stdout.write(self.style.SUCCESS(
            f'Created {len(created_users)} hosts and {len(slots)} slots '
            f'(total seeded hosts: {start_index + count}).'
        ))
