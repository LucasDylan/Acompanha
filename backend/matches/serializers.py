from django.contrib.auth import get_user_model
from rest_framework import serializers
from .models import MatchRequest

User = get_user_model()


class PartnerBriefSerializer(serializers.ModelSerializer):
    """Minimal user info shown in a match card."""
    class Meta:
        model = User
        fields = ['id', 'display_name', 'avatar_url']


class MatchRequestSerializer(serializers.ModelSerializer):
    sender = PartnerBriefSerializer(read_only=True)
    receiver = PartnerBriefSerializer(read_only=True)
    receiver_id = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(), write_only=True, source='receiver'
    )

    class Meta:
        model = MatchRequest
        fields = ['id', 'sender', 'receiver', 'receiver_id', 'status', 'created_at']
        read_only_fields = ['id', 'sender', 'status', 'created_at']

    def create(self, validated_data):
        validated_data['sender'] = self.context['request'].user
        return super().create(validated_data)
