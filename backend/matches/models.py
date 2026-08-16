"""
Match request model — mutual 'train together' requests between gym members.
A match is confirmed only when both users have accepted.
"""
from django.conf import settings
from django.db import models


class MatchRequest(models.Model):
    STATUS_PENDING = 'pending'
    STATUS_ACCEPTED = 'accepted'
    STATUS_DECLINED = 'declined'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending'),
        (STATUS_ACCEPTED, 'Accepted'),
        (STATUS_DECLINED, 'Declined'),
    ]

    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sent_requests',
    )
    receiver = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='received_requests',
    )
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default=STATUS_PENDING)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        # Prevent duplicate requests between same pair
        unique_together = [('sender', 'receiver')]
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.sender} → {self.receiver} ({self.status})'

    @classmethod
    def are_matched(cls, user_a, user_b):
        """Return True if both users have a mutual accepted match."""
        return cls.objects.filter(
            sender=user_a, receiver=user_b, status=cls.STATUS_ACCEPTED
        ).exists() or cls.objects.filter(
            sender=user_b, receiver=user_a, status=cls.STATUS_ACCEPTED
        ).exists()
