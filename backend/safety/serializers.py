from django.contrib.auth import get_user_model
from rest_framework import serializers

from chat.models import Conversation

from .models import Block, Report

User = get_user_model()


class BlockSerializer(serializers.ModelSerializer):
    """Someone the caller blocked."""
    user_id = serializers.IntegerField(source='blocked_id', read_only=True)
    display_name = serializers.CharField(source='blocked.display_name', read_only=True)
    avatar_url = serializers.SerializerMethodField()
    blocked_at = serializers.DateTimeField(source='created_at', read_only=True)

    class Meta:
        model = Block
        fields = ['user_id', 'display_name', 'avatar_url', 'blocked_at']

    def get_avatar_url(self, obj):
        return obj.blocked.avatar_absolute_url(self.context.get('request'))


class ReportSerializer(serializers.Serializer):
    user_id = serializers.PrimaryKeyRelatedField(queryset=User.objects.all())
    reason = serializers.ChoiceField(choices=Report.REASON_CHOICES)
    details = serializers.CharField(max_length=1000, required=False, allow_blank=True)
    conversation_id = serializers.PrimaryKeyRelatedField(
        queryset=Conversation.objects.all(), required=False, allow_null=True,
    )
    # Reporting usually comes with "and don't show me this person again".
    block = serializers.BooleanField(default=False)

    def validate(self, data):
        user = self.context['request'].user
        reported = data['user_id']
        if reported == user:
            raise serializers.ValidationError({'user_id': 'Você não pode denunciar a si mesmo.'})
        conversation = data.get('conversation_id')
        if conversation and not (conversation.includes(user) and conversation.includes(reported)):
            raise serializers.ValidationError({'conversation_id': 'Conversa não encontrada.'})
        return data
