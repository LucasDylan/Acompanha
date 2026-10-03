"""Create the Stripe Product/Price for the Personal Trainer Pro plan."""
import stripe
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

PRODUCT_NAME = 'Personal Trainer Pro'


class Command(BaseCommand):
    help = (
        'Create (once) the recurring Stripe price for the trainer Pro plan and '
        'print the id to put in STRIPE_TRAINER_PRICE_ID.'
    )

    def add_arguments(self, parser):
        parser.add_argument('--amount', type=int, default=1200, help='Monthly amount in BRL.')
        parser.add_argument('--currency', default='brl')

    def handle(self, *args, **options):
        if not settings.STRIPE_SECRET_KEY:
            raise CommandError('Set STRIPE_SECRET_KEY before running this.')

        stripe.api_key = settings.STRIPE_SECRET_KEY

        existing = stripe.Product.search(query=f'name:"{PRODUCT_NAME}" AND active:"true"')
        if existing['data']:
            product = existing['data'][0]
            self.stdout.write(f'Reusing product {product["id"]}.')
        else:
            product = stripe.Product.create(
                name=PRODUCT_NAME,
                description='Perfil de personal trainer visível na descoberta do app.',
            )
            self.stdout.write(f'Created product {product["id"]}.')

        price = stripe.Price.create(
            product=product['id'],
            unit_amount=options['amount'] * 100,
            currency=options['currency'],
            recurring={'interval': 'month'},
        )

        self.stdout.write(self.style.SUCCESS(
            f'\nPrice created: {price["id"]}\n'
            f'Add this to the backend environment:\n\n'
            f'    STRIPE_TRAINER_PRICE_ID={price["id"]}\n'
        ))
