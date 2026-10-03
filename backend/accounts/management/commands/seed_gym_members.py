"""Put demo users in a gym so the "train together" feed has people in it."""
import random

from django.core.management.base import BaseCommand

from accounts.models import User
from gyms.models import Gym

WORKOUT_TYPES = [
    'Musculação', 'Cardio', 'CrossFit', 'Funcional',
    'Pilates', 'Calistenia', 'Natação',
]
DAYS = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom']
LEVELS = [User.FITNESS_BEGINNER, User.FITNESS_INTERMEDIATE, User.FITNESS_ADVANCED]
BIOS = [
    'Treino de manhã cedo, gosto de constância.',
    'Foco em hipertrofia. Bora dividir a série?',
    'Voltando depois de um tempo parado — sem julgamento!',
    'Corrida + musculação. Odeio treinar sozinho.',
    'Meta: fechar a semana com 5 treinos.',
]


class Command(BaseCommand):
    help = 'Assign demo users (and optionally a real account) to a gym for testing the buddy feed.'

    def add_arguments(self, parser):
        parser.add_argument('--gym', default='Smart Fit Paulista', help='Gym name.')
        parser.add_argument('--city', default='São Paulo, SP')
        parser.add_argument('--count', type=int, default=25, help='How many demo users to put in the gym.')
        parser.add_argument(
            '--join',
            help='Username/email of an existing account to join the same gym (e.g. your test login).',
        )

    def handle(self, *args, **options):
        gym, created = Gym.objects.get_or_create(
            name=options['gym'],
            defaults={'city': options['city']},
        )
        self.stdout.write(
            self.style.SUCCESS(f'{"Created" if created else "Using"} gym: {gym.name} (id={gym.pk})')
        )

        members = list(
            User.objects.filter(username__startswith='seed_host_').order_by('id')[:options['count']]
        )
        for user in members:
            user.gym = gym
            user.fitness_level = random.choice(LEVELS)
            user.workout_types = random.sample(WORKOUT_TYPES, k=random.randint(1, 3))
            user.available_days = random.sample(DAYS, k=random.randint(2, 5))
            user.bio = random.choice(BIOS)
            user.age = random.randint(19, 48)
        User.objects.bulk_update(
            members, ['gym', 'fitness_level', 'workout_types', 'available_days', 'bio', 'age']
        )
        self.stdout.write(self.style.SUCCESS(f'Put {len(members)} demo users in {gym.name}.'))

        target = options.get('join')
        if target:
            user = User.objects.filter(username=target).first() or User.objects.filter(email=target).first()
            if not user:
                self.stdout.write(self.style.WARNING(f'No account matching "{target}" — skipped.'))
                return
            user.gym = gym
            user.save(update_fields=['gym'])
            self.stdout.write(self.style.SUCCESS(f'{user} now trains at {gym.name}.'))
