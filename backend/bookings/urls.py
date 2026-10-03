from django.urls import path

from .views import (
    BookingCancelView,
    BookingDetailView,
    BookingListCreateView,
    BookingReviewView,
    TrainingSessionCancelView,
    TrainingSessionConfirmView,
    TrainingSessionDetailView,
    TrainingSessionListCreateView,
)

urlpatterns = [
    path('sessions/', TrainingSessionListCreateView.as_view(), name='session-list'),
    path('sessions/<int:pk>/', TrainingSessionDetailView.as_view(), name='session-detail'),
    path('sessions/<int:pk>/confirm/', TrainingSessionConfirmView.as_view(), name='session-confirm'),
    path('sessions/<int:pk>/cancel/', TrainingSessionCancelView.as_view(), name='session-cancel'),
    path('bookings/', BookingListCreateView.as_view(), name='booking-list'),
    path('bookings/<int:pk>/', BookingDetailView.as_view(), name='booking-detail'),
    path('bookings/<int:pk>/cancel/', BookingCancelView.as_view(), name='booking-cancel'),
    path('bookings/<int:pk>/review/', BookingReviewView.as_view(), name='booking-review'),
]
