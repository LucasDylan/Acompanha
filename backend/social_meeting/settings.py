"""
Django settings for Acompanha API.
"""
import os
from decimal import Decimal
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

AUTH_USER_MODEL = 'accounts.User'

_DEV_SECRET_KEY = 'dev-secret-change-in-prod'
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', _DEV_SECRET_KEY)
DEBUG = os.environ.get('DJANGO_DEBUG', 'True').lower() == 'true'
if not DEBUG and SECRET_KEY == _DEV_SECRET_KEY:
    raise RuntimeError('Set DJANGO_SECRET_KEY to a long random value before running with DJANGO_DEBUG=False.')
# In production, set DJANGO_ALLOWED_HOSTS to a comma-separated list, e.g.
# "api.acompanha.app,acompanha.app". Defaults to "*" only for local dev.
ALLOWED_HOSTS = os.environ.get('DJANGO_ALLOWED_HOSTS', '*').split(',')

# User-facing API errors (DRF + password validators) come back in Portuguese,
# which is what the app shows on screen.
LANGUAGE_CODE = 'pt-br'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

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
    'chat',
    'safety',
    'legal',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    # Serves /static/ (admin CSS/JS) from the app server itself.
    'whitenoise.middleware.WhiteNoiseMiddleware',
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
# Hosted Postgres (Render, Railway, Neon, Supabase...) usually comes as one URL.
if os.environ.get('DATABASE_URL'):
    import dj_database_url

    DATABASES['default'] = dj_database_url.parse(
        os.environ['DATABASE_URL'], conn_max_age=600, conn_health_checks=True,
    )

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
    # Only views that set `throttle_scope` are throttled. The password-reset
    # limits are what keep a 6-digit code from being guessed by brute force.
    'DEFAULT_THROTTLE_CLASSES': ['rest_framework.throttling.ScopedRateThrottle'],
    'DEFAULT_THROTTLE_RATES': {
        'auth': '20/min',
        'password_reset': '5/hour',
        'password_reset_confirm': '20/hour',
        'messages': '60/min',
        'reports': '20/hour',
    },
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
# Publishable key handed to the app by GET /payments/config/ so the app doesn't
# need a rebuild to switch between test and live mode.
STRIPE_PUBLISHABLE_KEY = os.environ.get('STRIPE_PUBLISHABLE_KEY', '')
# When True, a booking is confirmed on creation without charging anything. Meant
# for local development before Stripe is set up — on by default only in DEBUG
# with no Stripe key, and never implied in production.
ALLOW_UNPAID_BOOKINGS = os.environ.get(
    'ALLOW_UNPAID_BOOKINGS',
    'True' if DEBUG and not STRIPE_SECRET_KEY else 'False',
).lower() == 'true'
# A booking waiting for payment holds its slot only this long.
BOOKING_PAYMENT_WINDOW_MINUTES = int(os.environ.get('BOOKING_PAYMENT_WINDOW_MINUTES', 30))
# Clients get a refund when they cancel at least this long before the meeting.
FREE_CANCELLATION_HOURS = int(os.environ.get('FREE_CANCELLATION_HOURS', 24))
# Recurring price for the Personal Trainer Pro plan. Create it once with
# `python manage.py setup_trainer_plan` and paste the printed price id here.
STRIPE_TRAINER_PRICE_ID = os.environ.get('STRIPE_TRAINER_PRICE_ID', '')
# Signing secret for POST /api/v1/payments/webhook/ (Stripe dashboard →
# Developers → Webhooks). Without it the endpoint rejects every event.
STRIPE_WEBHOOK_SECRET = os.environ.get('STRIPE_WEBHOOK_SECRET', '')
# Signing secret of the second webhook endpoint, the one for connected
# accounts' events (hosts' payout accounts: account.updated).
STRIPE_CONNECT_WEBHOOK_SECRET = os.environ.get('STRIPE_CONNECT_WEBHOOK_SECRET', '')
# Hosts get paid through Stripe Connect; the platform keeps this share (%).
PLATFORM_FEE_PERCENT = Decimal(os.environ.get('PLATFORM_FEE_PERCENT', '15'))

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
SUPPORT_EMAIL = os.environ.get('SUPPORT_EMAIL', 'suporte@acompanha.app')
# Who gets an e-mail for each user report (empty: only the admin queue).
MODERATION_EMAIL = os.environ.get('MODERATION_EMAIL', '')

CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOWED_ORIGINS = [] if DEBUG else [
    origin for origin in os.environ.get('CORS_ALLOWED_ORIGINS', '').split(',') if origin
]

if not DEBUG:
    # Behind a TLS-terminating proxy (Render, Railway, Fly, nginx...).
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    SECURE_SSL_REDIRECT = os.environ.get('SECURE_SSL_REDIRECT', 'True').lower() == 'true'
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = int(os.environ.get('SECURE_HSTS_SECONDS', 0))
    # The platform's health check calls over plain HTTP from inside its network.
    SECURE_REDIRECT_EXEMPT = [r'^healthz/$']
    CSRF_TRUSTED_ORIGINS = [
        origin for origin in os.environ.get('CSRF_TRUSTED_ORIGINS', '').split(',') if origin
    ]

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

STORAGES = {
    'default': {'BACKEND': 'django.core.files.storage.FileSystemStorage'},
    'staticfiles': {
        'BACKEND': 'django.contrib.staticfiles.storage.StaticFilesStorage' if DEBUG
        else 'whitenoise.storage.CompressedManifestStaticFilesStorage',
    },
}
# Photos in an S3-compatible bucket (AWS S3, Cloudflare R2...) instead of the
# server's disk. Credentials come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.
if os.environ.get('AWS_STORAGE_BUCKET_NAME'):
    STORAGES['default'] = {
        'BACKEND': 'storages.backends.s3.S3Storage',
        'OPTIONS': {
            'bucket_name': os.environ['AWS_STORAGE_BUCKET_NAME'],
            # R2: https://<account id>.r2.cloudflarestorage.com
            'endpoint_url': os.environ.get('AWS_S3_ENDPOINT_URL') or None,
            'region_name': os.environ.get('AWS_S3_REGION_NAME') or None,
            # Public domain of the bucket/CDN; without one, URLs are signed.
            'custom_domain': os.environ.get('AWS_S3_CUSTOM_DOMAIN') or None,
            'querystring_auth': not os.environ.get('AWS_S3_CUSTOM_DOMAIN'),
            'file_overwrite': False,
        },
    }

MEDIA_URL = '/media/'
MEDIA_ROOT = Path(os.environ.get('MEDIA_ROOT', BASE_DIR / 'media'))
# Let Django itself serve uploads when DEBUG is off (single-server deploys with
# a persistent disk). Leave off when a storage bucket/CDN serves them.
SERVE_MEDIA = os.environ.get('SERVE_MEDIA', 'False').lower() == 'true'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

UNFOLD = {
    'SITE_TITLE': 'Acompanha Admin',
    'SITE_HEADER': 'Acompanha',
    'SITE_SYMBOL': 'groups',
    'SHOW_HISTORY': True,
    'SHOW_VIEW_ON_SITE': True,
}

# Error monitoring: set SENTRY_DSN (sentry.io › project › Client Keys).
SENTRY_DSN = os.environ.get('SENTRY_DSN', '')
if SENTRY_DSN:
    import sentry_sdk

    sentry_sdk.init(
        dsn=SENTRY_DSN,
        environment=os.environ.get('SENTRY_ENVIRONMENT', 'development' if DEBUG else 'production'),
        traces_sample_rate=float(os.environ.get('SENTRY_TRACES_SAMPLE_RATE', '0')),
        send_default_pii=False,
    )
