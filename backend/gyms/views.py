from rest_framework import generics, filters
from rest_framework.permissions import IsAuthenticated, AllowAny
from .models import Gym
from .serializers import GymSerializer


class GymListCreateView(generics.ListCreateAPIView):
    """List all gyms (searchable) or create a new gym."""
    serializer_class = GymSerializer
    filter_backends = [filters.SearchFilter]
    search_fields = ['name', 'city']

    def get_permissions(self):
        if self.request.method == 'GET':
            return [AllowAny()]
        return [IsAuthenticated()]

    def get_queryset(self):
        return Gym.objects.all()


class GymDetailView(generics.RetrieveAPIView):
    """Get a single gym by ID."""
    serializer_class = GymSerializer
    queryset = Gym.objects.all()
    permission_classes = [IsAuthenticated]
