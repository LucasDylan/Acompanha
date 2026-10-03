import requests
from rest_framework import generics, status, filters
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError
from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.mail import send_mail

from .models import PasswordResetCode
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
        email = request.data.get('email')
        password = request.data.get('password')
        # Login é por e-mail, mas USERNAME_FIELD do User continua sendo
        # 'username' (herdado de AbstractUser) e muitas contas seedadas têm
        # username != email — então buscamos por e-mail direto em vez de
        # authenticate(username=email, ...), que comparava com o campo errado.
        user = User.objects.filter(email__iexact=email).first() if email else None
        if user and user.is_active and user.check_password(password):
            tokens = get_tokens_for_user(user)
            return Response({
                'user': UserSerializer(user).data,
                'access': tokens['access'],
                'refresh': tokens['refresh'],
            })
        return Response({'detail': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)


class FacebookLoginView(generics.GenericAPIView):
    """POST /api/v1/auth/facebook/ — exchange a Facebook access token (obtained
    client-side via the Facebook SDK) for our own JWT pair."""
    permission_classes = []

    def post(self, request):
        access_token = request.data.get('access_token')
        if not access_token:
            return Response({'detail': 'access_token is required'}, status=status.HTTP_400_BAD_REQUEST)

        app_id = settings.FACEBOOK_APP_ID
        app_secret = settings.FACEBOOK_APP_SECRET
        if not app_id or not app_secret:
            return Response(
                {'detail': 'Facebook login is not configured on the server.'},
                status=status.HTTP_501_NOT_IMPLEMENTED,
            )

        # Verify the token was actually issued to our app before trusting it.
        debug = requests.get(
            'https://graph.facebook.com/debug_token',
            params={'input_token': access_token, 'access_token': f'{app_id}|{app_secret}'},
            timeout=10,
        ).json().get('data', {})

        if not debug.get('is_valid') or str(debug.get('app_id')) != str(app_id):
            return Response({'detail': 'Invalid Facebook token'}, status=status.HTTP_401_UNAUTHORIZED)

        profile = requests.get(
            'https://graph.facebook.com/me',
            params={'fields': 'id,name,email,picture.type(large)', 'access_token': access_token},
            timeout=10,
        ).json()

        facebook_id = profile.get('id')
        email = profile.get('email')
        name = profile.get('name', '')
        avatar_url = profile.get('picture', {}).get('data', {}).get('url', '')

        user = User.objects.filter(facebook_id=facebook_id).first()
        if not user and email:
            user = User.objects.filter(email=email).first()
            if user:
                user.facebook_id = facebook_id
                user.save(update_fields=['facebook_id'])

        if not user:
            if not email:
                return Response(
                    {'detail': 'Seu Facebook não retornou um e-mail. Permita o acesso ao e-mail e tente novamente.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            user = User.objects.create_user(
                username=email,
                email=email,
                display_name=name,
                avatar_url=avatar_url,
                facebook_id=facebook_id,
            )
            user.set_unusable_password()
            user.save()

        tokens = get_tokens_for_user(user)
        return Response({
            'user': UserSerializer(user).data,
            'access': tokens['access'],
            'refresh': tokens['refresh'],
        })


class PasswordResetRequestView(generics.GenericAPIView):
    """POST /api/v1/auth/password-reset/ {email} — email a 6-digit reset code."""
    permission_classes = []

    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({'detail': 'email is required'}, status=status.HTTP_400_BAD_REQUEST)

        user = User.objects.filter(email=email).first()
        if user:
            code = PasswordResetCode.generate_code()
            PasswordResetCode.objects.create(user=user, code=code)
            send_mail(
                subject='Seu código de redefinição de senha — Acompanha',
                message=f'Seu código é {code}. Ele expira em 15 minutos.',
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                fail_silently=True,
            )
        # Same response whether or not the email exists, so callers can't use
        # this endpoint to discover which emails are registered.
        return Response({'detail': 'Se esse e-mail existir, um código foi enviado.'})


class PasswordResetConfirmView(generics.GenericAPIView):
    """POST /api/v1/auth/password-reset/confirm/ {email, code, new_password}."""
    permission_classes = []

    def post(self, request):
        email = request.data.get('email')
        code = request.data.get('code')
        new_password = request.data.get('new_password')
        if not (email and code and new_password):
            return Response(
                {'detail': 'email, code and new_password are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(email=email).first()
        reset_code = None
        if user:
            reset_code = user.password_reset_codes.filter(code=code, used=False).order_by('-created_at').first()

        if not user or not reset_code or not reset_code.is_valid():
            return Response({'detail': 'Código inválido ou expirado'}, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(new_password)
        user.save(update_fields=['password'])
        reset_code.used = True
        reset_code.save(update_fields=['used'])

        return Response({'detail': 'Senha atualizada'})


class RevokeTokenView(generics.GenericAPIView):
    """POST /api/v1/auth/revoke/ {refresh} — permanently invalidate a refresh
    token server-side. Used when the user removes a "saved account" from the
    login screen's quick-login list, so that token can't be replayed even if
    it was copied off the device before removal."""
    permission_classes = []

    def post(self, request):
        refresh = request.data.get('refresh')
        if not refresh:
            return Response({'detail': 'refresh is required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            RefreshToken(refresh).blacklist()
        except TokenError:
            pass  # Already invalid/expired/blacklisted — treat as success either way.
        return Response(status=status.HTTP_204_NO_CONTENT)


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

