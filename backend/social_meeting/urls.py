"""
URL configuration for Acompanha API.
"""
from django.conf import settings
from django.contrib import admin
from django.urls import include, path, re_path
from django.views.static import serve

from .views import healthz

urlpatterns = [
    path('healthz/', healthz),
    path('admin/', admin.site.urls),
    path('', include('legal.urls')),
    path('api/v1/', include('accounts.urls')),
    path('api/v1/', include('gyms.urls')),
    path('api/v1/', include('profiles.urls')),
    path('api/v1/', include('bookings.urls')),
    path('api/v1/', include('matches.urls')),
    path('api/v1/', include('payments.urls')),
    path('api/v1/', include('chat.urls')),
    path('api/v1/', include('safety.urls')),
]

# Uploaded photos. Fine for development and small deployments; at scale, point
# STORAGES['default'] at S3/R2 and let the CDN serve them instead.
if settings.DEBUG or settings.SERVE_MEDIA:
    urlpatterns += [
        re_path(r'^media/(?P<path>.*)$', serve, {'document_root': settings.MEDIA_ROOT}),
    ]
