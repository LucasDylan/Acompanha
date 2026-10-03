from django.urls import path

from .views import ConversationDetailView, ConversationListView, MessageListView, UnreadCountView

urlpatterns = [
    path('conversations/', ConversationListView.as_view()),
    path('conversations/unread-count/', UnreadCountView.as_view()),
    path('conversations/<int:pk>/', ConversationDetailView.as_view()),
    path('conversations/<int:pk>/messages/', MessageListView.as_view()),
]
