"""
Django settings for Acompanha API.
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

AUTH_USER_MODEL = 'accounts.User'

SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'dev-secret-change-in-prod')
DEBUG = os.environ.get('DJANGO_DEBUG', 'True').lower() == 'true'
# In production, set DJANGO_ALLOWED_HOSTS to a comma-separated list, e.g.
# "api.acompanha.app,acompanha.app". Defaults to "*" only for local dev.
ALLOWED_HOSTS = os.environ.get('DJANGO_ALLOWED_HOSTS', '*').split(',')

INSTALLED_APPS = [
    'unfold',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'corsheaders',
    'accounts',
    'gyms',
    'profiles',
    'bookings',
    'matches',
    'payments',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'social_meeting.urls'
WSGI_APPLICATION = 'social_meeting.wsgi.application'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'gymbuddy'),
        'USER': os.environ.get('DB_USER', 'gymbuddy'),
        'PASSWORD': os.environ.get('DB_PASSWORD', 'gymbuddy_dev'),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    # The Flutter client parses decimal fields (price_per_hour, amount, rating)
    # as JSON numbers, not strings — DRF defaults to string to avoid float
    # precision loss, but our client-side parsing needs real numbers.
    'COERCE_DECIMAL_TO_STRING': False,
}

from datetime import timedelta

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=1),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
}

# Facebook Login — create an app at https://developers.facebook.com/apps
# and set these as env vars (never commit the app secret).
FACEBOOK_APP_ID = os.environ.get('FACEBOOK_APP_ID', '')
FACEBOOK_APP_SECRET = os.environ.get('FACEBOOK_APP_SECRET', '')

# Stripe — get test/live secret keys from https://dashboard.stripe.com/apikeys
STRIPE_SECRET_KEY = os.environ.get('STRIPE_SECRET_KEY', '')
# Recurring price for the Personal Trainer Pro plan. Create it once with
# `python manage.py setup_trainer_plan` and paste the printed price id here.
STRIPE_TRAINER_PRICE_ID = os.environ.get('STRIPE_TRAINER_PRICE_ID', '')
# Signing secret for POST /api/v1/payments/webhook/ (Stripe dashboard →
# Developers → Webhooks). Without it the endpoint rejects every event.
STRIPE_WEBHOOK_SECRET = os.environ.get('STRIPE_WEBHOOK_SECRET', '')

# Email (password reset codes). Defaults to printing emails to the console in
# dev. For production, set EMAIL_BACKEND to the SMTP backend and fill in your
# provider's credentials (SendGrid, Mailgun, SES, Gmail app password, etc.) —
# any standard SMTP provider works, no code changes needed.
EMAIL_BACKEND = os.environ.get(
    'EMAIL_BACKEND',
    'django.core.mail.backends.console.EmailBackend' if DEBUG else 'django.core.mail.backends.smtp.EmailBackend',
)
EMAIL_HOST = os.environ.get('EMAIL_HOST', '')
EMAIL_PORT = int(os.environ.get('EMAIL_PORT', 587))
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')
EMAIL_USE_TLS = os.environ.get('EMAIL_USE_TLS', 'True').lower() == 'true'
DEFAULT_FROM_EMAIL = os.environ.get('DEFAULT_FROM_EMAIL', 'noreply@acompanha.app')

CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOWED_ORIGINS = [] if DEBUG else [
    origin for origin in os.environ.get('CORS_ALLOWED_ORIGINS', '').split(',') if origin
]

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

UNFOLD = {
    'SITE_TITLE': 'Acompanha Admin',
    'SITE_HEADER': 'Acompanha',
    'SITE_SYMBOL': 'groups',
    'SHOW_HISTORY': True,
    'SHOW_VIEW_ON_SITE': True,
}
