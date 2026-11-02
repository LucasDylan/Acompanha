from django.db import connection
from django.http import JsonResponse


def healthz(request):
    """For the hosting platform's health check: up and reaching the database."""
    connection.ensure_connection()
    return JsonResponse({'status': 'ok'})
