from rest_framework import serializers
from django.contrib.auth import get_user_model

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'email', 'display_name', 'avatar_url', 'role', 'is_host_profile_complete']
        read_only_fields = fields

    is_host_profile_complete = serializers.SerializerMethodField()

    def get_is_host_profile_complete(self, obj):
        return hasattr(obj, 'host_profile') and obj.host_profile is not None


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)

    class Meta:
        model = User
        fields = ['email', 'password', 'display_name', 'role']

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['email'],
            email=validated_data['email'],
            password=validated_data['password'],
            display_name=validated_data.get('display_name', ''),
            role=validated_data.get('role', 'client'),
        )
        return user
