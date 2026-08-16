from django.db.models import Q
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from .models import TrainingSession
from .serializers import TrainingSessionSerializer


class TrainingSessionListCreateView(generics.ListCreateAPIView):
    """List the user's sessions or create a new one with a matched partner."""
    serializer_class = TrainingSessionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return TrainingSession.objects.filter(
            Q(initiator=user) | Q(partner=user)
        )


class TrainingSessionDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Get, update (confirm/cancel) or delete a training session."""
    serializer_class = TrainingSessionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return TrainingSession.objects.filter(
            Q(initiator=user) | Q(partner=user)
        )
