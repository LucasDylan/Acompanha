from django.urls import path
from .views import (
    SendMatchRequestView,
    IncomingRequestsView,
    MyMatchesView,
    respond_to_request,
)

urlpatterns = [
    path('matches/request/', SendMatchRequestView.as_view(), name='match-send'),
    path('matches/incoming/', IncomingRequestsView.as_view(), name='match-incoming'),
    path('matches/', MyMatchesView.as_view(), name='match-list'),
    path('matches/<int:pk>/respond/', respond_to_request, name='match-respond'),
]
