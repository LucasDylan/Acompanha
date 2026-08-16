from rest_framework import generics, status, filters
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model

from .serializers import UserSerializer, RegisterSerializer, UpdateProfileSerializer

User = get_user_model()


def get_tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    }


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = []

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        tokens = get_tokens_for_user(user)
        return Response({
            'user': UserSerializer(user).data,
            'access': tokens['access'],
            'refresh': tokens['refresh'],
        }, status=status.HTTP_201_CREATED)


class LoginView(generics.GenericAPIView):
    permission_classes = []

    def post(self, request):
        from django.contrib.auth import authenticate
        email = request.data.get('email')
        password = request.data.get('password')
        user = authenticate(request, username=email, password=password)
        if user:
            tokens = get_tokens_for_user(user)
            return Response({
                'user': UserSerializer(user).data,
                'access': tokens['access'],
                'refresh': tokens['refresh'],
            })
        return Response({'detail': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)


class MeView(generics.RetrieveUpdateAPIView):
    """GET or PATCH /api/v1/me/ — read or update the current user's profile."""

    def get_serializer_class(self):
        if self.request.method in ('PATCH', 'PUT'):
            return UpdateProfileSerializer
        return UserSerializer

    def get_object(self):
        return self.request.user


class GymMembersView(generics.ListAPIView):
    """GET /api/v1/gym-members/ — discover other members of the authenticated user's gym."""
    serializer_class = UserSerializer
    filter_backends = [filters.SearchFilter]
    search_fields = ['display_name', 'fitness_level']

    def get_queryset(self):
        user = self.request.user
        if not user.gym_id:
            return User.objects.none()
        qs = User.objects.filter(gym=user.gym).exclude(pk=user.pk)
        # Optional filter by fitness level
        level = self.request.query_params.get('fitness_level')
        if level:
            qs = qs.filter(fitness_level=level)
        # Optional filter by workout type (substring match in JSON array)
        workout = self.request.query_params.get('workout_type')
        if workout:
            qs = qs.filter(workout_types__contains=workout)
        return qs

