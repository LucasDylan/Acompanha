from django.urls import path
from .views import GymListCreateView, GymDetailView

urlpatterns = [
    path('gyms/', GymListCreateView.as_view(), name='gym-list-create'),
    path('gyms/<int:pk>/', GymDetailView.as_view(), name='gym-detail'),
]
