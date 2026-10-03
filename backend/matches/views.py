from django.db.models import Q
from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import MatchRequest
from .serializers import MatchRequestSerializer


class SendMatchRequestView(generics.CreateAPIView):
    """Send a 'train together' request to another gym member."""
    serializer_class = MatchRequestSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):
        receiver_id = request.data.get('receiver_id')
        if str(receiver_id) == str(request.user.id):
            return Response({'detail': 'Você não pode enviar um pedido para si mesmo.'}, status=400)
        # Check if reverse request already exists and is pending → auto-accept
        reverse = MatchRequest.objects.filter(
            sender_id=receiver_id,
            receiver=request.user,
            status=MatchRequest.STATUS_PENDING,
        ).first()
        if reverse:
            reverse.status = MatchRequest.STATUS_ACCEPTED
            reverse.save()
            return Response(MatchRequestSerializer(reverse, context={'request': request}).data,
                            status=status.HTTP_200_OK)

        # Re-sending to the same person must not blow up on the
        # (sender, receiver) unique constraint — return what already stands.
        existing = MatchRequest.objects.filter(
            sender=request.user, receiver_id=receiver_id,
        ).first()
        if existing:
            return Response(MatchRequestSerializer(existing, context={'request': request}).data,
                            status=status.HTTP_200_OK)

        return super().create(request, *args, **kwargs)


class IncomingRequestsView(generics.ListAPIView):
    """List pending incoming match requests for the authenticated user."""
    serializer_class = MatchRequestSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return MatchRequest.objects.filter(
            receiver=self.request.user,
            sender__is_active=True,
            status=MatchRequest.STATUS_PENDING,
        ).select_related('sender', 'receiver')


class MyMatchesView(generics.ListAPIView):
    """List all accepted matches (mutual) for the authenticated user."""
    serializer_class = MatchRequestSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return MatchRequest.objects.filter(
            Q(sender=self.request.user) | Q(receiver=self.request.user),
            status=MatchRequest.STATUS_ACCEPTED,
            sender__is_active=True,
            receiver__is_active=True,
        ).select_related('sender', 'receiver')


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def respond_to_request(request, pk):
    """Accept or decline a pending match request."""
    try:
        match_req = MatchRequest.objects.get(pk=pk, receiver=request.user, status=MatchRequest.STATUS_PENDING)
    except MatchRequest.DoesNotExist:
        return Response({'detail': 'Pedido não encontrado.'}, status=404)
    action = request.data.get('action')
    if action == 'accept':
        match_req.status = MatchRequest.STATUS_ACCEPTED
    elif action == 'decline':
        match_req.status = MatchRequest.STATUS_DECLINED
    else:
        return Response({'detail': 'action deve ser "accept" ou "decline".'}, status=400)
    match_req.save()
    return Response(MatchRequestSerializer(match_req, context={'request': request}).data)
