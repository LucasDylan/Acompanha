from django.db import transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Booking, Review, TrainingSession
from .serializers import BookingSerializer, ReviewSerializer, TrainingSessionSerializer
from .services import (
    BookingError,
    cancel_booking,
    complete_finished_bookings,
    create_booking,
    expire_unpaid_bookings,
)


class TrainingSessionListCreateView(generics.ListCreateAPIView):
    """List the user's sessions or propose a new one to a matched partner."""
    serializer_class = TrainingSessionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        TrainingSession.objects.filter(
            Q(initiator=user) | Q(partner=user),
            status=TrainingSession.STATUS_CONFIRMED,
            scheduled_at__lt=timezone.now(),
        ).update(status=TrainingSession.STATUS_COMPLETED)
        return (
            TrainingSession.objects
            .filter(Q(initiator=user) | Q(partner=user))
            .select_related('initiator', 'partner')
            .order_by('-scheduled_at')
        )


class TrainingSessionDetailView(generics.RetrieveAPIView):
    serializer_class = TrainingSessionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return TrainingSession.objects.filter(Q(initiator=user) | Q(partner=user))


class TrainingSessionConfirmView(APIView):
    """POST /sessions/<id>/confirm/ — the invited partner accepts."""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        session = get_object_or_404(TrainingSession, pk=pk, partner=request.user)
        if session.status != TrainingSession.STATUS_PENDING:
            return Response({'detail': 'Este treino não está aguardando confirmação.'},
                            status=status.HTTP_400_BAD_REQUEST)
        if session.scheduled_at <= timezone.now():
            return Response({'detail': 'Este horário já passou.'}, status=status.HTTP_400_BAD_REQUEST)
        session.status = TrainingSession.STATUS_CONFIRMED
        session.save(update_fields=['status', 'updated_at'])
        return Response(TrainingSessionSerializer(session, context={'request': request}).data)


class TrainingSessionCancelView(APIView):
    """POST /sessions/<id>/cancel/ — either partner calls it off (or declines)."""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        session = get_object_or_404(
            TrainingSession.objects.filter(Q(initiator=request.user) | Q(partner=request.user)),
            pk=pk,
        )
        if session.status not in (TrainingSession.STATUS_PENDING, TrainingSession.STATUS_CONFIRMED):
            return Response({'detail': 'Este treino não pode mais ser cancelado.'},
                            status=status.HTTP_400_BAD_REQUEST)
        session.status = TrainingSession.STATUS_CANCELLED
        session.save(update_fields=['status', 'updated_at'])
        return Response(TrainingSessionSerializer(session, context={'request': request}).data)


class BookingPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


class BookingListCreateView(generics.ListCreateAPIView):
    """GET the caller's bookings (?role=host for the ones they received as a
    host), or POST {slot_id, host_id} to book an open slot."""
    serializer_class = BookingSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = BookingPagination

    def get_queryset(self):
        expire_unpaid_bookings()
        complete_finished_bookings()
        user = self.request.user
        if self.request.query_params.get('role') == 'host':
            qs = Booking.objects.filter(host__user=user)
        else:
            qs = Booking.objects.filter(client=user)
        return qs.select_related(
            'slot', 'host', 'host__user', 'client', 'payment', 'review',
        ).prefetch_related('host__photos').order_by('-slot__start_at')

    def create(self, request, *args, **kwargs):
        try:
            booking = create_booking(
                request.user, request.data.get('slot_id'), request.data.get('host_id'),
            )
        except BookingError as exc:
            return Response({'detail': exc.message}, status=exc.status)
        serializer = BookingSerializer(booking, context={'request': request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class BookingDetailView(generics.RetrieveAPIView):
    serializer_class = BookingSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return Booking.objects.filter(Q(client=user) | Q(host__user=user))


class BookingCancelView(APIView):
    """POST /bookings/<id>/cancel/ — client or host cancels, refunding per policy."""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            booking = cancel_booking(pk, request.user)
        except BookingError as exc:
            return Response({'detail': exc.message}, status=exc.status)
        return Response(BookingSerializer(booking, context={'request': request}).data)


class BookingReviewView(APIView):
    """POST /bookings/<id>/review/ {rating, comment} — the client rates a meeting
    that already happened. One review per booking."""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        complete_finished_bookings()
        booking = get_object_or_404(Booking.objects.select_related('host'), pk=pk, client=request.user)
        if booking.status != Booking.STATUS_COMPLETED:
            return Response({'detail': 'Você pode avaliar depois que o encontro acontecer.'},
                            status=status.HTTP_400_BAD_REQUEST)
        if Review.objects.filter(booking=booking).exists():
            return Response({'detail': 'Você já avaliou este encontro.'}, status=status.HTTP_400_BAD_REQUEST)

        serializer = ReviewSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        with transaction.atomic():
            review = serializer.save(booking=booking)
            Review.refresh_host_rating(booking.host)
        return Response(ReviewSerializer(review).data, status=status.HTTP_201_CREATED)
