from django.urls import path
from . import views

urlpatterns = [
    path('profiles/me/', views.MyHostProfileView.as_view()),
    path('profiles/hosts/', views.HostProfileListView.as_view()),
    path('profiles/<int:pk>/', views.HostProfileDetailView.as_view()),
    path('profiles/<int:pk>/photos/', views.HostProfilePhotoView.as_view()),
    path('profiles/<int:pk>/reviews/', views.HostReviewsView.as_view()),
    path('profiles/<int:host_id>/slots/', views.HostSlotsView.as_view()),
    path('profiles/<int:host_id>/slots/<int:pk>/', views.HostSlotDetailView.as_view()),
]
