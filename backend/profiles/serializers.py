from rest_framework import serializers
from .models import HostProfile, ProfilePhoto


class ProfilePhotoSerializer(serializers.ModelSerializer):
    url = serializers.SerializerMethodField()

    class Meta:
        model = ProfilePhoto
        fields = ['id', 'url', 'order']

    def get_url(self, obj):
        request = self.context.get('request')
        if obj.photo and request:
            return request.build_absolute_uri(obj.photo.url)
        return ''


class HostProfileSerializer(serializers.ModelSerializer):
    photos = serializers.SerializerMethodField()
    avatar_url = serializers.SerializerMethodField()
    user_id = serializers.SerializerMethodField()

    class Meta:
        model = HostProfile
        fields = ['id', 'user_id', 'display_name', 'bio', 'avatar_url', 'photos',
                  'categories', 'price_per_hour', 'currency', 'rating', 'review_count', 'location']

    def get_photos(self, obj):
        urls = []
        request = self.context.get('request')
        for p in obj.photos.all().order_by('order'):
            if p.photo and request:
                urls.append(request.build_absolute_uri(p.photo.url))
        return urls

    def get_avatar_url(self, obj):
        if obj.avatar and self.context.get('request'):
            return self.context['request'].build_absolute_uri(obj.avatar.url)
        return None

    def get_user_id(self, obj):
        return str(obj.user_id)
