from django.contrib.auth import get_user_model
from django.db.models import Case, Count, F, Q, When
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from safety.models import exclude_blocked, is_blocked

from .models import Conversation, Message, can_start_chat
from .serializers import ConversationSerializer, MessageSerializer, SendMessageSerializer

User = get_user_model()
PAGE = 50


def conversations_for(user):
    mine = Conversation.objects.filter(Q(user_a=user) | Q(user_b=user))
    # A chat with someone blocked (either way) is gone for both of them.
    mine = exclude_blocked(exclude_blocked(mine, user, 'user_a'), user, 'user_b')
    return (
        mine
        .select_related('user_a', 'user_b')
        .annotate(
            my_last_read=Case(
                When(user_a=user, then=F('user_a_last_read_at')),
                default=F('user_b_last_read_at'),
            ),
        )
        .annotate(
            unread=Count(
                'messages',
                filter=~Q(messages__sender=user) & (
                    Q(my_last_read__isnull=True) | Q(messages__created_at__gt=F('my_last_read'))
                ),
            ),
        )
    )


class ConversationListView(APIView):
    """GET /conversations/ — the caller's chats, newest activity first.
    POST /conversations/ {user_id} — open (or reopen) the chat with someone."""

    def get(self, request):
        qs = (
            conversations_for(request.user)
            .filter(last_message_at__isnull=False)
            .order_by('-last_message_at')
        )
        data = ConversationSerializer(qs, many=True, context={'request': request}).data
        return Response(data)

    def post(self, request):
        other = User.objects.filter(pk=request.data.get('user_id'), is_active=True).first()
        if other is None:
            return Response({'detail': 'Pessoa não encontrada.'}, status=status.HTTP_404_NOT_FOUND)
        if is_blocked(request.user, other):
            return Response(
                {'detail': 'Não é possível conversar com esta pessoa.'}, status=status.HTTP_403_FORBIDDEN,
            )
        a, b = sorted([request.user.pk, other.pk])
        existing = Conversation.objects.filter(user_a_id=a, user_b_id=b).first()
        if existing is None and not can_start_chat(request.user, other):
            return Response(
                {'detail': 'Vocês podem conversar depois de uma reserva ou de virarem parceiros de treino.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        conversation = existing or Conversation.between(request.user, other)
        conversation = conversations_for(request.user).get(pk=conversation.pk)
        return Response(ConversationSerializer(conversation, context={'request': request}).data)


class ConversationDetailView(APIView):
    def get(self, request, pk):
        conversation = get_object_or_404(conversations_for(request.user), pk=pk)
        return Response(ConversationSerializer(conversation, context={'request': request}).data)


class UnreadCountView(APIView):
    """GET /conversations/unread-count/ — total for the tab badge."""

    def get(self, request):
        total = sum(c.unread for c in conversations_for(request.user))
        return Response({'unread': total})


class MessageListView(APIView):
    """GET /conversations/<id>/messages/?after=<message id> — oldest first. Without
    `after`, the latest page. Reading marks the conversation as read.
    POST {text} sends a message."""
    throttle_scope = 'messages'

    def get_throttles(self):
        # Only sending is rate-limited; the app polls GET every few seconds.
        return super().get_throttles() if self.request.method == 'POST' else []

    def _conversation(self, request, pk):
        conversation = get_object_or_404(Conversation, pk=pk)
        if not conversation.includes(request.user):
            return None
        if is_blocked(request.user, conversation.other(request.user)):
            return None
        return conversation

    def get(self, request, pk):
        conversation = self._conversation(request, pk)
        if conversation is None:
            return Response({'detail': 'Conversa não encontrada.'}, status=status.HTTP_404_NOT_FOUND)

        after = request.query_params.get('after')
        messages = conversation.messages.all()
        if after and str(after).isdigit():
            messages = messages.filter(pk__gt=int(after))[:PAGE]
        else:
            messages = list(messages.order_by('-id')[:PAGE])[::-1]
        conversation.mark_read(request.user)
        return Response(MessageSerializer(messages, many=True).data)

    def post(self, request, pk):
        conversation = self._conversation(request, pk)
        if conversation is None:
            return Response({'detail': 'Conversa não encontrada.'}, status=status.HTTP_404_NOT_FOUND)
        if not conversation.other(request.user).is_active:
            return Response({'detail': 'Esta conta não está mais ativa.'}, status=status.HTTP_400_BAD_REQUEST)

        serializer = SendMessageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        message = Message.objects.create(
            conversation=conversation,
            sender=request.user,
            text=serializer.validated_data['text'],
        )
        conversation.last_message_at = message.created_at
        conversation.save(update_fields=['last_message_at'])
        conversation.mark_read(request.user)
        return Response(MessageSerializer(message).data, status=status.HTTP_201_CREATED)
