"""
Direct messages between two people who have a reason to talk: a booking
between them (client and host) or an accepted gym-partner match.
"""
from django.conf import settings
from django.db import models
from django.db.models import Q
from django.utils import timezone


def can_start_chat(user, other):
    from bookings.models import Booking
    from matches.models import MatchRequest

    if user == other or not other.is_active:
        return False
    have_booking = Booking.objects.filter(
        Q(client=user, host__user=other) | Q(client=other, host__user=user),
    ).exclude(status=Booking.STATUS_CANCELLED).exists()
    return have_booking or MatchRequest.are_matched(user, other)


class Conversation(models.Model):
    # Stored with the lower user id in user_a so each pair has one row.
    user_a = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='+')
    user_b = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='+')
    user_a_last_read_at = models.DateTimeField(null=True, blank=True)
    user_b_last_read_at = models.DateTimeField(null=True, blank=True)
    last_message_at = models.DateTimeField(null=True, blank=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['user_a', 'user_b'], name='one_conversation_per_pair'),
            models.CheckConstraint(condition=Q(user_a__lt=models.F('user_b')), name='conversation_users_ordered'),
        ]

    def __str__(self):
        return f'{self.user_a} ↔ {self.user_b}'

    @classmethod
    def between(cls, user, other):
        a, b = sorted([user, other], key=lambda u: u.pk)
        conversation, _ = cls.objects.get_or_create(user_a=a, user_b=b)
        return conversation

    def includes(self, user):
        return user.pk in (self.user_a_id, self.user_b_id)

    def other(self, user):
        return self.user_b if user.pk == self.user_a_id else self.user_a

    def mark_read(self, user):
        field = 'user_a_last_read_at' if user.pk == self.user_a_id else 'user_b_last_read_at'
        setattr(self, field, timezone.now())
        self.save(update_fields=[field])


class Message(models.Model):
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='+')
    text = models.TextField(max_length=2000)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['id']

    def __str__(self):
        return f'{self.sender}: {self.text[:40]}'
