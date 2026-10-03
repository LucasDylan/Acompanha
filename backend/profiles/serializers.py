from decimal import Decimal

from rest_framework import serializers

from bookings.models import Booking

from .categories import normalize_categories
from .models import HostProfile, Slot


class HostProfileSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    user_id = serializers.SerializerMethodField()
    avatar_url = serializers.SerializerMethodField()
    photos = serializers.SerializerMethodField()
    categories = serializers.SerializerMethodField()

    class Meta:
        model = HostProfile
        fields = [
            'id', 'user_id', 'display_name', 'bio', 'avatar_url', 'photos',
            'categories', 'price_per_hour', 'currency', 'rating', 'review_count', 'location',
            'is_trainer', 'is_active',
        ]

    def get_id(self, obj):
        return str(obj.pk)

    def get_user_id(self, obj):
        return str(obj.user_id)

    def get_avatar_url(self, obj):
        return obj.user.avatar_absolute_url(self.context.get('request'))

    def get_photos(self, obj):
        request = self.context.get('request')
        urls = []
        for p in obj.photos.all():
            if p.photo:
                url = p.photo.url
                if request:
                    url = request.build_absolute_uri(url)
                urls.append(url)
        return urls

    def get_categories(self, obj):
        return normalize_categories(obj.categories)


class HostProfileUpsertSerializer(serializers.ModelSerializer):
    categories = serializers.ListField(child=serializers.CharField(max_length=60), required=False)
    price_per_hour = serializers.DecimalField(
        max_digits=8, decimal_places=2, min_value=Decimal('1'), max_value=Decimal('10000'),
    )

    class Meta:
        model = HostProfile
        fields = ['display_name', 'bio', 'categories', 'price_per_hour', 'location', 'is_active']
        extra_kwargs = {
            'display_name': {'required': True, 'allow_blank': False},
            'bio': {'max_length': 500},
        }

    def validate_categories(self, value):
        slugs = normalize_categories(value)
        if not slugs:
            raise serializers.ValidationError('Escolha pelo menos uma categoria.')
        return slugs

    def validate(self, attrs):
        if self.instance is None and not attrs.get('categories'):
            raise serializers.ValidationError({'categories': ['Escolha pelo menos uma categoria.']})
        return attrs


class SlotSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    host_id = serializers.SerializerMethodField()
    booking_id = serializers.SerializerMethodField()

    class Meta:
        model = Slot
        fields = ['id', 'host_id', 'start_at', 'end_at', 'status', 'booking_id']

    def get_id(self, obj):
        return str(obj.pk)

    def get_host_id(self, obj):
        return str(obj.host_id)

    def get_booking_id(self, obj):
        active = [b for b in obj.bookings.all() if b.status in Booking.ACTIVE_STATUSES]
        return str(active[0].pk) if active else None


class PhotoUploadSerializer(serializers.Serializer):
    image = serializers.ImageField()

    def validate_image(self, value):
        if value.size > 8 * 1024 * 1024:
            raise serializers.ValidationError('Cada foto deve ter no máximo 8 MB.')
        return value
