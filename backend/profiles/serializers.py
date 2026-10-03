from rest_framework import serializers
from .models import HostProfile, ProfilePhoto, Slot


class HostProfileSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    user_id = serializers.SerializerMethodField()
    avatar_url = serializers.SerializerMethodField()
    photos = serializers.SerializerMethodField()

    class Meta:
        model = HostProfile
        fields = [
            'id', 'user_id', 'display_name', 'bio', 'avatar_url', 'photos',
            'categories', 'price_per_hour', 'currency', 'rating', 'review_count', 'location',
            'is_trainer',
        ]

    def get_id(self, obj):
        return str(obj.pk)

    def get_user_id(self, obj):
        return str(obj.user_id)

    def get_avatar_url(self, obj):
        return obj.user.avatar_url or None

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


class HostProfileUpsertSerializer(serializers.ModelSerializer):
    class Meta:
        model = HostProfile
        fields = ['display_name', 'bio', 'categories', 'price_per_hour', 'location']


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
        booking = getattr(obj, 'booking', None)
        return str(booking.pk) if booking else None
