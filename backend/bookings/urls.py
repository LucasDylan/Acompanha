from django.urls import path
from .views import (
    TrainingSessionListCreateView, TrainingSessionDetailView,
    BookingListCreateView, BookingConfirmView, BookingCancelView,
)

urlpatterns = [
    path('sessions/', TrainingSessionListCreateView.as_view(), name='session-list'),
    path('sessions/<int:pk>/', TrainingSessionDetailView.as_view(), name='session-detail'),
    path('bookings/', BookingListCreateView.as_view(), name='booking-list'),
    path('bookings/<int:pk>/confirm/', BookingConfirmView.as_view(), name='booking-confirm'),
    path('bookings/<int:pk>/cancel/', BookingCancelView.as_view(), name='booking-cancel'),
]
