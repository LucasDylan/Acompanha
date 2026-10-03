import requests
from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.mail import send_mail
from django.db import transaction
from rest_framework import filters, generics, serializers, status
from rest_framework.pagination import PageNumberPagination
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from matches.models import MatchRequest

from .models import PasswordResetCode
from .serializers import (
    AvatarSerializer,
    PublicUserSerializer,
    RegisterSerializer,
    UpdateProfileSerializer,
    UserSerializer,
)
from .services import delete_account, revoke_all_sessions

User = get_user_model()


def get_tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    }


def auth_response(user, request, status_code=status.HTTP_200_OK):
    tokens = get_tokens_for_user(user)
    return Response({
        'user': UserSerializer(user, context={'request': request}).data,
        'access': tokens['access'],
        'refresh': tokens['refresh'],
    }, status=status_code)


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = []
    throttle_scope = 'auth'

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return auth_response(user, request, status.HTTP_201_CREATED)


class LoginView(generics.GenericAPIView):
    permission_classes = []
    throttle_scope = 'auth'

    def post(self, request):
        email = (request.data.get('email') or '').strip()
        password = request.data.get('password') or ''
        # Login é por e-mail, mas USERNAME_FIELD do User continua sendo
        # 'username' (herdado de AbstractUser) e muitas contas seedadas têm
        # username != email — então buscamos por e-mail direto em vez de
        # authenticate(username=email, ...), que comparava com o campo errado.
        user = User.objects.filter(email__iexact=email).first() if email else None
        if user and user.is_active and user.check_password(password):
            return auth_response(user, request)
        return Response({'detail': 'E-mail ou senha incorretos.'}, status=status.HTTP_401_UNAUTHORIZED)


class FacebookLoginView(generics.GenericAPIView):
    """POST /api/v1/auth/facebook/ — exchange a Facebook access token (obtained
    client-side via the Facebook SDK) for our own JWT pair."""
    permission_classes = []
    throttle_scope = 'auth'

    def post(self, request):
        access_token = request.data.get('access_token')
        if not access_token:
            return Response({'detail': 'access_token is required'}, status=status.HTTP_400_BAD_REQUEST)

        app_id = settings.FACEBOOK_APP_ID
        app_secret = settings.FACEBOOK_APP_SECRET
        if not app_id or not app_secret:
            return Response(
                {'detail': 'O login com Facebook ainda não está configurado.'},
                status=status.HTTP_501_NOT_IMPLEMENTED,
            )

        try:
            # Verify the token was actually issued to our app before trusting it.
            debug = requests.get(
                'https://graph.facebook.com/debug_token',
                params={'input_token': access_token, 'access_token': f'{app_id}|{app_secret}'},
                timeout=10,
            ).json().get('data', {})
            if not debug.get('is_valid') or str(debug.get('app_id')) != str(app_id):
                return Response({'detail': 'Token do Facebook inválido.'}, status=status.HTTP_401_UNAUTHORIZED)

            profile = requests.get(
                'https://graph.facebook.com/me',
                params={'fields': 'id,name,email,picture.type(large)', 'access_token': access_token},
                timeout=10,
            ).json()
        except requests.RequestException:
            return Response({'detail': 'Não foi possível falar com o Facebook. Tente novamente.'},
                            status=status.HTTP_502_BAD_GATEWAY)

        facebook_id = profile.get('id')
        email = (profile.get('email') or '').strip().lower()
        name = profile.get('name', '')
        avatar_url = profile.get('picture', {}).get('data', {}).get('url', '')

        user = User.objects.filter(facebook_id=facebook_id).first()
        if not user and email:
            user = User.objects.filter(email__iexact=email).first()
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

        if not user.is_active:
            return Response({'detail': 'Esta conta foi desativada.'}, status=status.HTTP_403_FORBIDDEN)
        return auth_response(user, request)


class PasswordResetRequestView(generics.GenericAPIView):
    """POST /api/v1/auth/password-reset/ {email} — email a 6-digit reset code."""
    permission_classes = []
    throttle_scope = 'password_reset'

    def post(self, request):
        email = (request.data.get('email') or '').strip()
        if not email:
            return Response({'detail': 'Informe o e-mail.'}, status=status.HTTP_400_BAD_REQUEST)

        user = User.objects.filter(email__iexact=email, is_active=True).first()
        if user:
            # Only the newest code works.
            user.password_reset_codes.filter(used=False).update(used=True)
            code = PasswordResetCode.generate_code()
            PasswordResetCode.objects.create(user=user, code=code)
            send_mail(
                subject='Seu código de redefinição de senha — Acompanha',
                message=f'Seu código é {code}. Ele expira em 15 minutos.',
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[user.email],
                fail_silently=True,
            )
        # Same response whether or not the email exists, so callers can't use
        # this endpoint to discover which emails are registered.
        return Response({'detail': 'Se esse e-mail existir, um código foi enviado.'})


class PasswordResetConfirmView(generics.GenericAPIView):
    """POST /api/v1/auth/password-reset/confirm/ {email, code, new_password}."""
    permission_classes = []
    throttle_scope = 'password_reset_confirm'

    def post(self, request):
        email = (request.data.get('email') or '').strip()
        code = (request.data.get('code') or '').strip()
        new_password = request.data.get('new_password')
        if not (email and code and new_password):
            return Response(
                {'detail': 'Informe e-mail, código e a nova senha.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        invalid = Response({'detail': 'Código inválido ou expirado.'}, status=status.HTTP_400_BAD_REQUEST)
        user = User.objects.filter(email__iexact=email, is_active=True).first()
        if not user:
            return invalid

        with transaction.atomic():
            reset_code = (
                user.password_reset_codes.select_for_update()
                .filter(used=False).order_by('-created_at').first()
            )
            if not reset_code or not reset_code.is_valid():
                return invalid
            if reset_code.code != code:
                reset_code.failed_attempts += 1
                reset_code.save(update_fields=['failed_attempts'])
                return invalid

            try:
                validate_password(new_password, user=user)
            except DjangoValidationError as exc:
                return Response({'new_password': list(exc.messages), 'detail': ' '.join(exc.messages)},
                                status=status.HTTP_400_BAD_REQUEST)

            user.set_password(new_password)
            user.save(update_fields=['password'])
            reset_code.used = True
            reset_code.save(update_fields=['used'])
            # Whoever had the old password shouldn't keep a session.
            revoke_all_sessions(user)

        return Response({'detail': 'Senha atualizada.'})


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


class MeView(generics.RetrieveUpdateDestroyAPIView):
    """GET or PATCH /api/v1/auth/me/ — read or update the current user's profile.
    DELETE closes the account (required by the App Store for apps with sign-up)."""

    def get_serializer_class(self):
        if self.request.method in ('PATCH', 'PUT'):
            return UpdateProfileSerializer
        return UserSerializer

    def get_object(self):
        return self.request.user

    def destroy(self, request, *args, **kwargs):
        delete_account(request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)


class AvatarView(APIView):
    """POST (multipart 'image') sets the user's profile photo; DELETE removes it."""
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        serializer = AvatarSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = request.user
        if user.avatar:
            user.avatar.delete(save=False)
        user.avatar = serializer.validated_data['image']
        user.save(update_fields=['avatar'])
        return Response(UserSerializer(user, context={'request': request}).data)

    def delete(self, request):
        user = request.user
        if user.avatar:
            user.avatar.delete(save=False)
        user.avatar = None
        user.avatar_url = ''
        user.save(update_fields=['avatar', 'avatar_url'])
        return Response(UserSerializer(user, context={'request': request}).data)


class GymMemberSerializer(PublicUserSerializer):
    """A gym mate, plus where the caller stands with them:
    none | sent | received | matched."""
    match_status = serializers.SerializerMethodField()

    class Meta(PublicUserSerializer.Meta):
        fields = PublicUserSerializer.Meta.fields + ['match_status']

    def get_match_status(self, obj):
        return self.context.get('match_status', {}).get(obj.pk, 'none')


class GymMembersPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


class GymMembersView(generics.ListAPIView):
    """GET /api/v1/gym-members/ — discover other members of the authenticated user's gym."""
    serializer_class = GymMemberSerializer
    pagination_class = GymMembersPagination
    filter_backends = [filters.SearchFilter]
    search_fields = ['display_name']

    def get_queryset(self):
        user = self.request.user
        if not user.gym_id:
            return User.objects.none()
        qs = (
            User.objects.filter(gym=user.gym, is_active=True)
            .exclude(pk=user.pk)
            .select_related('gym')
            .order_by('display_name', 'id')
        )
        level = self.request.query_params.get('fitness_level')
        if level:
            qs = qs.filter(fitness_level=level)
        workout = self.request.query_params.get('workout_type')
        if workout:
            qs = qs.filter(workout_types__contains=[workout])
        return qs

    def get_serializer_context(self):
        context = super().get_serializer_context()
        user = self.request.user
        statuses = {}
        for req in MatchRequest.objects.filter(receiver=user).exclude(status=MatchRequest.STATUS_DECLINED):
            statuses[req.sender_id] = 'matched' if req.status == MatchRequest.STATUS_ACCEPTED else 'received'
        for req in MatchRequest.objects.filter(sender=user):
            if req.status == MatchRequest.STATUS_ACCEPTED:
                statuses[req.receiver_id] = 'matched'
            else:
                # A declined request still reads as "sent" to the sender.
                statuses.setdefault(req.receiver_id, 'sent')
        context['match_status'] = statuses
        return context
