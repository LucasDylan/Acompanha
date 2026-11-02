from django.urls import path

from .views import BlockDetailView, BlockListView, ReportView

urlpatterns = [
    path('blocks/', BlockListView.as_view()),
    path('blocks/<int:user_id>/', BlockDetailView.as_view()),
    path('reports/', ReportView.as_view()),
]
