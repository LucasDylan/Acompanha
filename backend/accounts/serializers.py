from rest_framework import serializers
from django.contrib.auth import get_user_model
from gyms.serializers import GymSerializer

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    gym = GymSerializer(read_only=True)

    class Meta:
        model = User
        fields = [
            'id', 'email', 'display_name', 'avatar_url',
            'gym', 'fitness_level', 'workout_types', 'available_days',
            'bio', 'age',
        ]
        read_only_fields = ['id', 'email']


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    gym_id = serializers.IntegerField(required=False, allow_null=True, write_only=True)

    class Meta:
        model = User
        fields = ['email', 'password', 'display_name', 'gym_id']

    def create(self, validated_data):
        gym_id = validated_data.pop('gym_id', None)
        user = User.objects.create_user(
            username=validated_data['email'],
            email=validated_data['email'],
            password=validated_data['password'],
            display_name=validated_data.get('display_name', ''),
        )
        if gym_id:
            from gyms.models import Gym
            try:
                user.gym = Gym.objects.get(pk=gym_id)
                user.save()
            except Gym.DoesNotExist:
                pass
        return user


class UpdateProfileSerializer(serializers.ModelSerializer):
    """PATCH /api/v1/me/ — update fitness profile fields."""
    gym_id = serializers.IntegerField(required=False, allow_null=True, write_only=True)

    class Meta:
        model = User
        fields = [
            'display_name', 'avatar_url', 'gym_id',
            'fitness_level', 'workout_types', 'available_days', 'bio', 'age',
        ]

    def update(self, instance, validated_data):
        gym_id = validated_data.pop('gym_id', None)
        if gym_id is not None:
            from gyms.models import Gym
            try:
                instance.gym = Gym.objects.get(pk=gym_id)
            except Gym.DoesNotExist:
                pass
        return super().update(instance, validated_data)

