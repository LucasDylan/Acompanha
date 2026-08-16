from django.urls import path
from .views import TrainingSessionListCreateView, TrainingSessionDetailView

urlpatterns = [
    path('sessions/', TrainingSessionListCreateView.as_view(), name='session-list'),
    path('sessions/<int:pk>/', TrainingSessionDetailView.as_view(), name='session-detail'),
]
