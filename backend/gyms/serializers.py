from rest_framework import serializers
from .models import Gym


class GymSerializer(serializers.ModelSerializer):
    member_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Gym
        fields = ['id', 'name', 'address', 'city', 'member_count']
