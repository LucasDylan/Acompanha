from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.utils import timezone
from rest_framework import serializers

from gyms.serializers import GymSerializer

User = get_user_model()

WEEK_DAYS = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom']


class PublicUserSerializer(serializers.ModelSerializer):
    """What other people may see about a user — never the e-mail."""
    gym = GymSerializer(read_only=True)
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'display_name', 'avatar_url',
            'gym', 'fitness_level', 'workout_types', 'available_days',
            'bio', 'age',
        ]

    def get_avatar_url(self, obj):
        return obj.avatar_absolute_url(self.context.get('request'))


class UserSerializer(PublicUserSerializer):
    """The logged-in user's own account."""
    is_host = serializers.SerializerMethodField()
    host_profile_id = serializers.SerializerMethodField()

    class Meta(PublicUserSerializer.Meta):
        fields = PublicUserSerializer.Meta.fields + ['email', 'is_host', 'host_profile_id']
        read_only_fields = ['id', 'email']

    def get_is_host(self, obj):
        return hasattr(obj, 'host_profile')

    def get_host_profile_id(self, obj):
        profile = getattr(obj, 'host_profile', None)
        return str(profile.pk) if profile else None


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    gym_id = serializers.IntegerField(required=False, allow_null=True, write_only=True)
    # "I'm 18 or older and accept the terms of use and privacy policy."
    accept_terms = serializers.BooleanField(write_only=True)

    class Meta:
        model = User
        fields = ['email', 'password', 'display_name', 'gym_id', 'accept_terms']
        extra_kwargs = {'email': {'required': True, 'allow_blank': False}}

    def validate_email(self, value):
        value = value.strip().lower()
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError('Já existe uma conta com este e-mail.')
        return value

    def validate_accept_terms(self, value):
        if not value:
            raise serializers.ValidationError(
                'Para criar a conta, confirme que tem 18 anos ou mais e aceita os Termos de uso.'
            )
        return value

    def validate(self, attrs):
        candidate = User(email=attrs['email'], display_name=attrs.get('display_name', ''))
        try:
            validate_password(attrs['password'], user=candidate)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({'password': list(exc.messages)})
        return attrs

    def create(self, validated_data):
        gym_id = validated_data.pop('gym_id', None)
        user = User.objects.create_user(
            username=validated_data['email'],
            email=validated_data['email'],
            password=validated_data['password'],
            display_name=validated_data.get('display_name', ''),
            terms_accepted_at=timezone.now(),
        )
        if gym_id:
            from gyms.models import Gym
            user.gym = Gym.objects.filter(pk=gym_id).first()
            user.save(update_fields=['gym'])
        return user


class UpdateProfileSerializer(serializers.ModelSerializer):
    """PATCH /api/v1/auth/me/ — the user's own name, gym and fitness profile."""
    gym_id = serializers.IntegerField(required=False, allow_null=True, write_only=True)
    workout_types = serializers.ListField(
        child=serializers.CharField(max_length=40), max_length=10, required=False,
    )
    available_days = serializers.ListField(
        child=serializers.ChoiceField(choices=WEEK_DAYS), max_length=7, required=False,
    )
    age = serializers.IntegerField(min_value=16, max_value=100, required=False, allow_null=True)

    class Meta:
        model = User
        fields = [
            'display_name', 'gym_id',
            'fitness_level', 'workout_types', 'available_days', 'bio', 'age',
        ]
        extra_kwargs = {'bio': {'max_length': 500}}

    def validate_gym_id(self, value):
        if value is None:
            return None
        from gyms.models import Gym
        gym = Gym.objects.filter(pk=value).first()
        if gym is None:
            raise serializers.ValidationError('Academia não encontrada.')
        return gym

    def validate_available_days(self, value):
        return [day for day in WEEK_DAYS if day in value]

    def update(self, instance, validated_data):
        if 'gym_id' in validated_data:
            instance.gym = validated_data.pop('gym_id')
        return super().update(instance, validated_data)

    def to_representation(self, instance):
        return UserSerializer(instance, context=self.context).data


class AvatarSerializer(serializers.Serializer):
    image = serializers.ImageField()

    def validate_image(self, value):
        if value.size > 8 * 1024 * 1024:
            raise serializers.ValidationError('A foto deve ter no máximo 8 MB.')
        return value
