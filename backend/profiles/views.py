from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils.dateparse import parse_datetime
from rest_framework import generics, status
from rest_framework.pagination import PageNumberPagination
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework.views import APIView

from payments.models import TrainerSubscription

from .models import HostProfile, ProfilePhoto, Slot
from .serializers import HostProfileSerializer, HostProfileUpsertSerializer, SlotSerializer


class HostPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 50


class MyHostProfileView(APIView):
    """GET or POST /profiles/me/ — view or upsert the caller's own host listing."""

    def get(self, request):
        profile = getattr(request.user, 'host_profile', None)
        if profile is None:
            return Response({'detail': 'No host profile yet'}, status=status.HTTP_404_NOT_FOUND)
        return Response(HostProfileSerializer(profile, context={'request': request}).data)

    def post(self, request):
        profile = getattr(request.user, 'host_profile', None)
        serializer = HostProfileUpsertSerializer(
            instance=profile, data=request.data, partial=True,
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
            .filter(is_active=True)
            .select_related('user', 'trainer_subscription')
        )

        # Professional trainers are what the Pro plan pays for: they only show
        # up here while that subscription is active. Everyone else is unaffected.
        qs = qs.filter(
            Q(is_trainer=False)
            | Q(is_trainer=True, trainer_subscription__status=TrainerSubscription.STATUS_ACTIVE)
        )

        categories = self.request.query_params.get('categories')
        if categories:
            cats = [c.strip() for c in categories.split(',') if c.strip()]
            cat_filter = Q()
            for c in cats:
                cat_filter |= Q(categories__contains=[c])
            qs = qs.filter(cat_filter)

        min_price = self.request.query_params.get('min_price')
        if min_price:
            qs = qs.filter(price_per_hour__gte=min_price)

        max_price = self.request.query_params.get('max_price')
        if max_price:
            qs = qs.filter(price_per_hour__lte=max_price)

        location = self.request.query_params.get('location')
        if location:
            qs = qs.filter(location__icontains=location)

        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(Q(display_name__icontains=search) | Q(bio__icontains=search))

        return qs


class HostProfileDetailView(generics.RetrieveAPIView):
    """GET /profiles/<id>/ — a single host's public listing."""
    queryset = HostProfile.objects.select_related('user')
    serializer_class = HostProfileSerializer


class HostProfilePhotoView(APIView):
    """POST (multipart, field 'image') / DELETE (body {'url': ...}) a host's gallery photo."""
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, pk):
        profile = get_object_or_404(HostProfile, pk=pk)
        image = request.data.get('image')
        if not image:
            return Response({'detail': 'image is required'}, status=status.HTTP_400_BAD_REQUEST)

        order = profile.photos.count()
        photo = ProfilePhoto.objects.create(host_profile=profile, photo=image, order=order)
        url = photo.photo.url
        url = request.build_absolute_uri(url)
        return Response({'image': url}, status=status.HTTP_201_CREATED)

    def delete(self, request, pk):
        profile = get_object_or_404(HostProfile, pk=pk)
        url = request.data.get('url')
        if not url:
            return Response({'detail': 'url is required'}, status=status.HTTP_400_BAD_REQUEST)

        for p in profile.photos.all():
            if p.photo and (p.photo.url in url or url.endswith(p.photo.url)):
                p.delete()
                return Response(status=status.HTTP_204_NO_CONTENT)
        return Response({'detail': 'Photo not found'}, status=status.HTTP_404_NOT_FOUND)


class HostSlotsView(generics.ListCreateAPIView):
    """GET /profiles/<host_id>/slots/?from=<iso datetime> — a host's bookable slots.

    POST (same URL) lets the host who owns that profile publish a new slot:
    body {"start_at": iso datetime, "end_at": iso datetime}.
    """
    serializer_class = SlotSerializer

    def get_queryset(self):
        qs = Slot.objects.filter(host_id=self.kwargs['host_id'])
        from_param = self.request.query_params.get('from')
        if from_param:
            dt = parse_datetime(from_param)
            if dt:
                qs = qs.filter(start_at__gte=dt)
        return qs

    def create(self, request, *args, **kwargs):
        host_id = self.kwargs['host_id']
        profile = get_object_or_404(HostProfile, pk=host_id)
        if profile.user_id != request.user.id:
            return Response(
                {'detail': 'You can only manage your own availability.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        start_at = parse_datetime(request.data.get('start_at') or '')
        end_at = parse_datetime(request.data.get('end_at') or '')
        if not start_at or not end_at:
            return Response(
                {'detail': 'start_at and end_at must be valid ISO datetimes.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        duration_minutes = (end_at - start_at).total_seconds() / 60
        if duration_minutes < 30 or duration_minutes > 480:
            return Response(
                {'detail': 'Slot duration must be between 30 and 480 minutes.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        slot = Slot.objects.create(host=profile, start_at=start_at, end_at=end_at)
        return Response(SlotSerializer(slot).data, status=status.HTTP_201_CREATED)


class HostSlotDetailView(generics.RetrieveDestroyAPIView):
    """DELETE /profiles/<host_id>/slots/<pk>/ — the owning host cancels an open slot."""
    serializer_class = SlotSerializer

    def get_queryset(self):
        return Slot.objects.filter(host_id=self.kwargs['host_id'])

    def destroy(self, request, *args, **kwargs):
        slot = self.get_object()
        if slot.host.user_id != request.user.id:
            return Response(
                {'detail': 'You can only manage your own availability.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        if slot.status != Slot.STATUS_AVAILABLE:
            return Response(
                {'detail': 'Only open (unbooked) slots can be removed.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        slot.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
