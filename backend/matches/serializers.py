from django.contrib.auth import get_user_model
from rest_framework import serializers

from .models import MatchRequest

User = get_user_model()


class PartnerBriefSerializer(serializers.ModelSerializer):
    """Minimal user info shown in a match card."""
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'display_name', 'avatar_url']

    def get_avatar_url(self, obj):
        return obj.avatar_absolute_url(self.context.get('request'))


class MatchRequestSerializer(serializers.ModelSerializer):
    sender = PartnerBriefSerializer(read_only=True)
    receiver = PartnerBriefSerializer(read_only=True)
    receiver_id = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.filter(is_active=True), write_only=True, source='receiver'
    )

    class Meta:
        model = MatchRequest
        fields = ['id', 'sender', 'receiver', 'receiver_id', 'status', 'created_at']
        read_only_fields = ['id', 'sender', 'status', 'created_at']

    def validate_receiver_id(self, receiver):
        user = self.context['request'].user
        if receiver == user:
            raise serializers.ValidationError('Você não pode enviar um pedido para si mesmo.')
        if not user.gym_id or receiver.gym_id != user.gym_id:
            raise serializers.ValidationError('Vocês precisam treinar na mesma academia.')
        return receiver

    def create(self, validated_data):
        validated_data['sender'] = self.context['request'].user
        return super().create(validated_data)
