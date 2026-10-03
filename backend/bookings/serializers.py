from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import serializers

from matches.models import MatchRequest
from profiles.serializers import HostProfileSerializer, SlotSerializer

from .models import Booking, Review, TrainingSession
from .services import refund_due

User = get_user_model()


class PartnerBriefSerializer(serializers.ModelSerializer):
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'display_name', 'avatar_url', 'fitness_level']

    def get_avatar_url(self, obj):
        return obj.avatar_absolute_url(self.context.get('request'))


class TrainingSessionSerializer(serializers.ModelSerializer):
    initiator = PartnerBriefSerializer(read_only=True)
    partner = PartnerBriefSerializer(read_only=True)
    partner_id = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.filter(is_active=True), write_only=True, source='partner'
    )
    duration_minutes = serializers.IntegerField(min_value=15, max_value=480, required=False)

    class Meta:
        model = TrainingSession
        fields = [
            'id', 'initiator', 'partner', 'partner_id',
            'gym', 'scheduled_at', 'duration_minutes',
            'workout_type', 'notes', 'status', 'created_at',
        ]
        read_only_fields = ['id', 'initiator', 'gym', 'status', 'created_at']

    def validate_scheduled_at(self, value):
        if value <= timezone.now():
            raise serializers.ValidationError('Escolha um horário no futuro.')
        return value

    def validate_partner_id(self, partner):
        user = self.context['request'].user
        if partner == user:
            raise serializers.ValidationError('Escolha um parceiro de treino.')
        if not MatchRequest.are_matched(user, partner):
            raise serializers.ValidationError('Vocês precisam ser parceiros para marcar um treino.')
        return partner

    def create(self, validated_data):
        user = self.context['request'].user
        validated_data['initiator'] = user
        validated_data['gym'] = user.gym
        return super().create(validated_data)


class ClientBriefSerializer(serializers.ModelSerializer):
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'display_name', 'avatar_url']

    def get_avatar_url(self, obj):
        return obj.avatar_absolute_url(self.context.get('request'))


class ReviewSerializer(serializers.ModelSerializer):
    author = serializers.SerializerMethodField()

    class Meta:
        model = Review
        fields = ['id', 'rating', 'comment', 'created_at', 'author']
        read_only_fields = ['id', 'created_at', 'author']

    def get_author(self, obj):
        client = obj.booking.client
        return client.display_name or 'Cliente'


class BookingSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    client_id = serializers.SerializerMethodField()
    host_id = serializers.SerializerMethodField()
    host_user_id = serializers.SerializerMethodField()
    slot_id = serializers.SerializerMethodField()
    start_at = serializers.SerializerMethodField()
    end_at = serializers.SerializerMethodField()
    slot = SlotSerializer(read_only=True)
    host = HostProfileSerializer(read_only=True)
    client = ClientBriefSerializer(read_only=True)
    payment_status = serializers.SerializerMethodField()
    cancelled_by_host = serializers.SerializerMethodField()
    refundable_if_cancelled = serializers.SerializerMethodField()
    review = serializers.SerializerMethodField()

    class Meta:
        model = Booking
        fields = [
            'id', 'client_id', 'host_id', 'host_user_id', 'slot_id', 'status',
            'amount', 'currency', 'slot', 'host', 'client', 'start_at', 'end_at',
            'payment_status', 'cancelled_at', 'cancelled_by_host',
            'refundable_if_cancelled', 'review', 'created_at',
        ]

    def get_id(self, obj):
        return str(obj.pk)

    def get_client_id(self, obj):
        return str(obj.client_id)

    def get_host_id(self, obj):
        return str(obj.host_id)

    def get_host_user_id(self, obj):
        return str(obj.host.user_id)

    def get_slot_id(self, obj):
        return str(obj.slot_id)

    def get_start_at(self, obj):
        return obj.slot.start_at

    def get_end_at(self, obj):
        return obj.slot.end_at

    def get_payment_status(self, obj):
        # Missing reverse one-to-ones raise a subclass of AttributeError, so
        # getattr's default covers "no payment yet".
        payment = getattr(obj, 'payment', None)
        return payment.status if payment else None

    def get_cancelled_by_host(self, obj):
        return bool(obj.cancelled_by_id and obj.cancelled_by_id == obj.host.user_id)

    def get_refundable_if_cancelled(self, obj):
        """For the person looking at it: would cancelling now refund the client?"""
        if obj.status not in (Booking.STATUS_PENDING, Booking.STATUS_CONFIRMED):
            return False
        request = self.context.get('request')
        by_host = bool(request and obj.host.user_id == request.user.id)
        return refund_due(obj, by_host)

    def get_review(self, obj):
        review = getattr(obj, 'review', None)
        return ReviewSerializer(review).data if review else None
