from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import TrainingSession

User = get_user_model()


class PartnerBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'display_name', 'avatar_url', 'fitness_level']


class TrainingSessionSerializer(serializers.ModelSerializer):
    initiator = PartnerBriefSerializer(read_only=True)
    partner = PartnerBriefSerializer(read_only=True)
    partner_id = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(), write_only=True, source='partner'
    )

    class Meta:
        model = TrainingSession
        fields = [
            'id', 'initiator', 'partner', 'partner_id',
            'gym', 'scheduled_at', 'duration_minutes',
            'workout_type', 'notes', 'status', 'created_at',
        ]
        read_only_fields = ['id', 'initiator', 'status', 'created_at']

    def create(self, validated_data):
        validated_data['initiator'] = self.context['request'].user
        # Auto-assign gym from initiator
        if 'gym' not in validated_data and self.context['request'].user.gym:
            validated_data['gym'] = self.context['request'].user.gym
        return super().create(validated_data)
