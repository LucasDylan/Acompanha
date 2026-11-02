from datetime import timedelta

from django.db.models import F, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from rest_framework import generics, status
from rest_framework.pagination import PageNumberPagination
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from bookings.services import expire_unpaid_bookings
from payments.connect import READY_HOSTS, payouts_required
from safety.models import exclude_blocked

from .categories import normalize_categories
from .models import HostProfile, ProfilePhoto, Slot
from .serializers import (
    HostProfileSerializer,
    HostProfileUpsertSerializer,
    PhotoUploadSerializer,
    SlotSerializer,
)

MAX_PHOTOS = 6
# How far ahead the booking calendar looks.
SLOT_HORIZON_DAYS = 120
FORBIDDEN_OTHER_PROFILE = 'Você só pode alterar o seu próprio perfil.'


class HostPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 50


class MyHostProfileView(APIView):
    """GET or POST /profiles/me/ — view or upsert the caller's own host listing."""

    def get(self, request):
        profile = getattr(request.user, 'host_profile', None)
        if profile is None:
            return Response({'detail': 'Você ainda não tem perfil de anfitrião.'},
                            status=status.HTTP_404_NOT_FOUND)
        return Response(HostProfileSerializer(profile, context={'request': request}).data)

    def post(self, request):
        profile = getattr(request.user, 'host_profile', None)
        serializer = HostProfileUpsertSerializer(
            instance=profile, data=request.data, partial=profile is not None,
        )
        serializer.is_valid(raise_exception=True)
        profile = serializer.save(user=request.user)
        return Response(HostProfileSerializer(profile, context={'request': request}).data)


class HostProfileListView(generics.ListAPIView):
    """GET /profiles/hosts/ — discovery feed of active hosts."""
    serializer_class = HostProfileSerializer
    pagination_class = HostPagination

    def get_queryset(self):
        qs = (
            HostProfile.objects
            .filter(is_active=True, user__is_active=True)
            .exclude(user=self.request.user)
            .select_related('user')
            .prefetch_related('photos')
            .order_by(F('rating').desc(nulls_last=True), '-review_count', 'id')
        )
        qs = exclude_blocked(qs, self.request.user, 'user')
        if payouts_required():
            # Only hosts who can actually be paid (and so booked).
            qs = qs.filter(READY_HOSTS)

        categories = normalize_categories(
            (self.request.query_params.get('categories') or '').split(','),
        )
        if categories:
            cat_filter = Q()
            for c in categories:
                cat_filter |= Q(categories__contains=[c])
            qs = qs.filter(cat_filter)

        if self.request.query_params.get('trainer') in ('1', 'true'):
            qs = qs.filter(is_trainer=True)

        min_price = self.request.query_params.get('min_price')
        if min_price:
            qs = qs.filter(price_per_hour__gte=min_price)

        max_price = self.request.query_params.get('max_price')
        if max_price:
            qs = qs.filter(price_per_hour__lte=max_price)

        location = self.request.query_params.get('location')
        if location:
            qs = qs.filter(location__icontains=location.strip())

        search = (self.request.query_params.get('search') or '').strip()
        if search:
            qs = qs.filter(
                Q(display_name__icontains=search)
                | Q(bio__icontains=search)
                | Q(location__icontains=search)
            )

        return qs


class HostProfileDetailView(generics.RetrieveAPIView):
    """GET /profiles/<id>/ — a single host's public listing."""
    serializer_class = HostProfileSerializer

    def get_queryset(self):
        qs = (
            HostProfile.objects
            .filter(Q(is_active=True, user__is_active=True) | Q(user=self.request.user))
            .select_related('user')
            .prefetch_related('photos')
        )
        return exclude_blocked(qs, self.request.user, 'user')


class HostReviewsView(generics.ListAPIView):
    """GET /profiles/<id>/reviews/ — what clients said after meeting this host."""

    def get_serializer_class(self):
        from bookings.serializers import ReviewSerializer
        return ReviewSerializer

    def get_queryset(self):
        from bookings.models import Review
        return (
            Review.objects.filter(booking__host_id=self.kwargs['pk'])
            .select_related('booking__client')
            .order_by('-created_at')
        )


class HostProfilePhotoView(APIView):
    """POST (multipart, field 'image') / DELETE (body {'url': ...}) a photo of
    the caller's own listing."""
    parser_classes = [MultiPartParser, FormParser]

    def _own_profile(self, request, pk):
        profile = get_object_or_404(HostProfile, pk=pk)
        if profile.user_id != request.user.id:
            return None
        return profile

    def post(self, request, pk):
        profile = self._own_profile(request, pk)
        if profile is None:
            return Response({'detail': FORBIDDEN_OTHER_PROFILE}, status=status.HTTP_403_FORBIDDEN)
        if profile.photos.count() >= MAX_PHOTOS:
            return Response({'detail': f'Máximo de {MAX_PHOTOS} fotos.'}, status=status.HTTP_400_BAD_REQUEST)

        serializer = PhotoUploadSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        photo = ProfilePhoto.objects.create(
            host_profile=profile,
            photo=serializer.validated_data['image'],
            order=profile.photos.count(),
        )
        return Response({'image': request.build_absolute_uri(photo.photo.url)},
                        status=status.HTTP_201_CREATED)

    def delete(self, request, pk):
        profile = self._own_profile(request, pk)
        if profile is None:
            return Response({'detail': FORBIDDEN_OTHER_PROFILE}, status=status.HTTP_403_FORBIDDEN)
        url = request.data.get('url')
        if not url:
            return Response({'detail': 'url is required'}, status=status.HTTP_400_BAD_REQUEST)

        for p in profile.photos.all():
            if p.photo and url.endswith(p.photo.url):
                p.photo.delete(save=False)
                p.delete()
                return Response(status=status.HTTP_204_NO_CONTENT)
        return Response({'detail': 'Foto não encontrada.'}, status=status.HTTP_404_NOT_FOUND)


class HostSlotsView(generics.ListCreateAPIView):
    """GET /profiles/<host_id>/slots/ — the host's upcoming slots. Everyone else
    sees only the open ones; the host also sees booked ones.

    POST (same URL) lets the host who owns that profile publish a new slot:
    body {"start_at": iso datetime, "end_at": iso datetime}.
    """
    serializer_class = SlotSerializer
    pagination_class = None

    def get_queryset(self):
        expire_unpaid_bookings()
        host_id = self.kwargs['host_id']
        now = timezone.now()
        qs = Slot.objects.filter(
            host_id=host_id,
            start_at__gt=now,
            start_at__lt=now + timedelta(days=SLOT_HORIZON_DAYS),
        ).prefetch_related('bookings').order_by('start_at')

        is_owner = HostProfile.objects.filter(pk=host_id, user=self.request.user).exists()
        if is_owner:
            return qs.exclude(status=Slot.STATUS_CANCELLED)
        return exclude_blocked(qs, self.request.user, 'host__user').filter(status=Slot.STATUS_AVAILABLE)

    def create(self, request, *args, **kwargs):
        profile = get_object_or_404(HostProfile, pk=self.kwargs['host_id'])
        if profile.user_id != request.user.id:
            return Response({'detail': 'Você só pode gerenciar a sua própria agenda.'},
                            status=status.HTTP_403_FORBIDDEN)

        start_at = parse_datetime(request.data.get('start_at') or '')
        end_at = parse_datetime(request.data.get('end_at') or '')
        if not start_at or not end_at:
            return Response({'detail': 'Informe início e fim do horário.'},
                            status=status.HTTP_400_BAD_REQUEST)
        if timezone.is_naive(start_at) or timezone.is_naive(end_at):
            return Response({'detail': 'Envie o horário com fuso (ISO 8601 com offset).'},
                            status=status.HTTP_400_BAD_REQUEST)
        if start_at <= timezone.now():
            return Response({'detail': 'O horário precisa ser no futuro.'},
                            status=status.HTTP_400_BAD_REQUEST)
        duration_minutes = (end_at - start_at).total_seconds() / 60
        if duration_minutes < 30 or duration_minutes > 480:
            return Response({'detail': 'A duração precisa ficar entre 30 minutos e 8 horas.'},
                            status=status.HTTP_400_BAD_REQUEST)
        overlaps = Slot.objects.filter(
            host=profile,
            status__in=[Slot.STATUS_AVAILABLE, Slot.STATUS_BOOKED],
            start_at__lt=end_at,
            end_at__gt=start_at,
        ).exists()
        if overlaps:
            return Response({'detail': 'Já existe um horário seu nesse intervalo.'},
                            status=status.HTTP_400_BAD_REQUEST)

        slot = Slot.objects.create(host=profile, start_at=start_at, end_at=end_at)
        return Response(SlotSerializer(slot).data, status=status.HTTP_201_CREATED)


class HostSlotDetailView(generics.RetrieveDestroyAPIView):
    """DELETE /profiles/<host_id>/slots/<pk>/ — the owning host removes an open slot."""
    serializer_class = SlotSerializer

    def get_queryset(self):
        return Slot.objects.filter(host_id=self.kwargs['host_id']).prefetch_related('bookings')

    def destroy(self, request, *args, **kwargs):
        slot = self.get_object()
        if slot.host.user_id != request.user.id:
            return Response({'detail': 'Você só pode gerenciar a sua própria agenda.'},
                            status=status.HTTP_403_FORBIDDEN)
        if slot.status != Slot.STATUS_AVAILABLE:
            return Response({'detail': 'Só dá para remover horários sem reserva. '
                                       'Para os reservados, cancele a reserva.'},
                            status=status.HTTP_400_BAD_REQUEST)
        slot.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
