from decimal import Decimal

from django.db.models import Q
from django.shortcuts import get_object_or_404
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from profiles.models import Slot
from .models import TrainingSession, Booking
from .serializers import TrainingSessionSerializer, BookingSerializer


class TrainingSessionListCreateView(generics.ListCreateAPIView):
    """List the user's sessions or create a new one with a matched partner."""
    serializer_class = TrainingSessionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return TrainingSession.objects.filter(
            Q(initiator=user) | Q(partner=user)
        )


class BookingListCreateView(generics.ListCreateAPIView):
    """GET the caller's paid bookings, or POST to book a host's open slot."""
    serializer_class = BookingSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Booking.objects.filter(client=self.request.user)

    def create(self, request, *args, **kwargs):
        slot_id = request.data.get('slot_id')
        host_id = request.data.get('host_id')
        slot = get_object_or_404(Slot, pk=slot_id, host_id=host_id)
        if slot.status != Slot.STATUS_AVAILABLE:
            return Response({'detail': 'This slot is no longer available.'}, status=status.HTTP_400_BAD_REQUEST)

        host = slot.host
        duration_hours = Decimal((slot.end_at - slot.start_at).total_seconds()) / Decimal(3600)
        amount = (host.price_per_hour or Decimal('0')) * duration_hours

        booking = Booking.objects.create(
            client=request.user,
            host=host,
            slot=slot,
            amount=amount.quantize(Decimal('0.01')),
            currency=host.currency,
        )
        slot.status = Slot.STATUS_BOOKED
        slot.save(update_fields=['status'])

        serializer = BookingSerializer(booking, context={'request': request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class BookingConfirmView(APIView):
    """POST /bookings/<id>/confirm/ — mark a booking confirmed (post-payment)."""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        booking = get_object_or_404(
            Booking.objects.filter(Q(client=request.user) | Q(host__user=request.user)),
            pk=pk,
        )
        booking.status = Booking.STATUS_CONFIRMED
        booking.save(update_fields=['status', 'updated_at'])
        return Response(BookingSerializer(booking, context={'request': request}).data)


class BookingCancelView(APIView):
    """POST /bookings/<id>/cancel/ — cancel a booking and free its slot."""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        booking = get_object_or_404(
            Booking.objects.filter(Q(client=request.user) | Q(host__user=request.user)),
            pk=pk,
        )
        booking.status = Booking.STATUS_CANCELLED
        booking.save(update_fields=['status', 'updated_at'])
        booking.slot.status = Slot.STATUS_AVAILABLE
        booking.slot.save(update_fields=['status'])
        return Response(BookingSerializer(booking, context={'request': request}).data)


class TrainingSessionDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Get, update (confirm/cancel) or delete a training session."""
    serializer_class = TrainingSessionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        return TrainingSession.objects.filter(
            Q(initiator=user) | Q(partner=user)
        )
