from rest_framework import serializers
from django.contrib.auth import get_user_model
from profiles.serializers import HostProfileSerializer, SlotSerializer
from .models import TrainingSession, Booking

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


class BookingSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    client_id = serializers.SerializerMethodField()
    host_id = serializers.SerializerMethodField()
    slot_id = serializers.SerializerMethodField()
    start_at = serializers.SerializerMethodField()
    end_at = serializers.SerializerMethodField()
    slot = SlotSerializer(read_only=True)
    host = HostProfileSerializer(read_only=True)

    class Meta:
        model = Booking
        fields = [
            'id', 'client_id', 'host_id', 'slot_id', 'status', 'amount', 'currency',
            'slot', 'host', 'start_at', 'end_at', 'created_at',
        ]

    def get_id(self, obj):
        return str(obj.pk)

    def get_client_id(self, obj):
        return str(obj.client_id)

    def get_host_id(self, obj):
        return str(obj.host_id)

    def get_slot_id(self, obj):
        return str(obj.slot_id)

    def get_start_at(self, obj):
        return obj.slot.start_at

    def get_end_at(self, obj):
        return obj.slot.end_at
