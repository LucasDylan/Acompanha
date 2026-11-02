# Acompanha API: docker build -t acompanha-api . && docker run -p 8000:8000 --env-file .env acompanha-api
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
# Static files (admin CSS/JS) are baked into the image and served by WhiteNoise.
RUN DJANGO_DEBUG=False DJANGO_SECRET_KEY=collectstatic-only python manage.py collectstatic --noinput

RUN useradd --create-home app && chown -R app /app
USER app

EXPOSE 8000
# Applies pending migrations, then serves. Fine for a single instance; with
# several, run "python manage.py migrate" as a release step instead.
CMD ["sh", "-c", "python manage.py migrate --noinput && exec gunicorn social_meeting.wsgi --bind 0.0.0.0:${PORT} --workers ${WEB_CONCURRENCY:-3} --access-logfile -"]
