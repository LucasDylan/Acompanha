"""
Blocking and reporting people — the app stores require both wherever users
can reach each other (chat, host listings, gym partners).

A block works both ways: neither person sees the other in discovery or the
gym list, and they can't message, book or send partner requests to each other.
"""
from django.conf import settings
from django.db import models
from django.db.models import Q


class Block(models.Model):
    blocker = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='blocks_made')
    blocked = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='blocked_by')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'bloqueio'
        constraints = [
            models.UniqueConstraint(fields=['blocker', 'blocked'], name='one_block_per_pair'),
        ]

    def __str__(self):
        return f'{self.blocker} bloqueou {self.blocked}'


def is_blocked(user, other):
    """True if either of them blocked the other."""
    return Block.objects.filter(
        Q(blocker=user, blocked=other) | Q(blocker=other, blocked=user),
    ).exists()


def exclude_blocked(queryset, user, field='pk'):
    """Drop rows whose `field` (a user) blocked `user` or was blocked by them."""
    return queryset.exclude(
        **{f'{field}__in': Block.objects.filter(blocker=user).values('blocked')},
    ).exclude(
        **{f'{field}__in': Block.objects.filter(blocked=user).values('blocker')},
    )


class Report(models.Model):
    REASON_SPAM = 'spam'
    REASON_HARASSMENT = 'harassment'
    REASON_SEXUAL = 'sexual'
    REASON_FAKE = 'fake'
    REASON_SAFETY = 'safety'
    REASON_OTHER = 'other'
    REASON_CHOICES = [
        (REASON_SPAM, 'Spam ou golpe'),
        (REASON_HARASSMENT, 'Assédio ou ofensa'),
        (REASON_SEXUAL, 'Conteúdo ou proposta sexual'),
        (REASON_FAKE, 'Perfil falso'),
        (REASON_SAFETY, 'Me senti inseguro(a)'),
        (REASON_OTHER, 'Outro motivo'),
    ]

    STATUS_OPEN = 'open'
    STATUS_REVIEWED = 'reviewed'
    STATUS_CHOICES = [(STATUS_OPEN, 'Aberta'), (STATUS_REVIEWED, 'Analisada')]

    # Kept when the reporter closes their account, so moderation history stays.
    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='reports_made',
    )
    reported = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='reports_received')
    reason = models.CharField(max_length=16, choices=REASON_CHOICES)
    details = models.TextField(max_length=1000, blank=True)
    # The chat it came from, so moderators can read what was said.
    conversation = models.ForeignKey(
        'chat.Conversation', on_delete=models.SET_NULL, null=True, blank=True, related_name='+',
    )
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default=STATUS_OPEN, db_index=True)
    moderator_note = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = 'denúncia'
        ordering = ['-created_at']

    def __str__(self):
        return f'Denúncia #{self.pk}: {self.reported} ({self.get_reason_display()})'
