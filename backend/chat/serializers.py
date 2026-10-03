from rest_framework import serializers

from .models import Conversation, Message


class ChatUserSerializer(serializers.Serializer):
    id = serializers.SerializerMethodField()
    display_name = serializers.CharField()
    avatar_url = serializers.SerializerMethodField()

    def get_id(self, obj):
        return str(obj.pk)

    def get_avatar_url(self, obj):
        return obj.avatar_absolute_url(self.context.get('request'))


class MessageSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    sender_id = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ['id', 'sender_id', 'text', 'created_at']

    def get_id(self, obj):
        return str(obj.pk)

    def get_sender_id(self, obj):
        return str(obj.sender_id)


class SendMessageSerializer(serializers.Serializer):
    text = serializers.CharField(max_length=2000, trim_whitespace=True)


class ConversationSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    other_user = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = ['id', 'other_user', 'last_message', 'unread_count', 'last_message_at']

    def _me(self):
        return self.context['request'].user

    def get_id(self, obj):
        return str(obj.pk)

    def get_other_user(self, obj):
        return ChatUserSerializer(obj.other(self._me()), context=self.context).data

    def get_last_message(self, obj):
        last = obj.messages.order_by('-id').first()
        return MessageSerializer(last).data if last else None

    def get_unread_count(self, obj):
        annotated = getattr(obj, 'unread', None)
        if annotated is not None:
            return annotated
        me = self._me()
        last_read = obj.user_a_last_read_at if me.pk == obj.user_a_id else obj.user_b_last_read_at
        qs = obj.messages.exclude(sender=me)
        if last_read:
            qs = qs.filter(created_at__gt=last_read)
        return qs.count()
