from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Block
from .serializers import BlockSerializer, ReportSerializer
from .services import block_user, report_user, unblock_user

User = get_user_model()


class BlockListView(APIView):
    """GET /blocks/ — people the caller blocked. POST {user_id} blocks someone."""

    def get(self, request):
        blocks = Block.objects.filter(blocker=request.user).select_related('blocked').order_by('-created_at')
        return Response(BlockSerializer(blocks, many=True, context={'request': request}).data)

    def post(self, request):
        other = User.objects.filter(pk=request.data.get('user_id')).first()
        if other is None:
            return Response({'detail': 'Pessoa não encontrada.'}, status=status.HTTP_404_NOT_FOUND)
        if other == request.user:
            return Response({'detail': 'Você não pode bloquear a si mesmo.'}, status=status.HTTP_400_BAD_REQUEST)
        block = block_user(request.user, other)
        return Response(BlockSerializer(block, context={'request': request}).data, status=status.HTTP_201_CREATED)


class BlockDetailView(APIView):
    """DELETE /blocks/<user_id>/ — unblock."""

    def delete(self, request, user_id):
        unblock_user(request.user, user_id)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ReportView(APIView):
    """POST /reports/ {user_id, reason, details?, conversation_id?, block?}"""
    throttle_scope = 'reports'

    def post(self, request):
        serializer = ReportSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        report = report_user(
            request.user,
            data['user_id'],
            data['reason'],
            details=data.get('details', '').strip(),
            conversation=data.get('conversation_id'),
        )
        if data['block']:
            block_user(request.user, data['user_id'])
        return Response({'id': report.pk, 'blocked': data['block']}, status=status.HTTP_201_CREATED)
