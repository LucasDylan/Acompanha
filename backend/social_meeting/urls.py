"""
URL configuration for GymBuddy API.
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/v1/', include('accounts.urls')),
    path('api/v1/', include('gyms.urls')),
    path('api/v1/', include('profiles.urls')),
    path('api/v1/', include('bookings.urls')),
    path('api/v1/', include('matches.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

