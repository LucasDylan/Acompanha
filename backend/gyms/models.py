"""
Gym model — users register with a gym; discovery is scoped to gym members.
"""
from django.db import models


class Gym(models.Model):
    name = models.CharField(max_length=255)
    address = models.CharField(max_length=512, blank=True)
    city = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name

    @property
    def member_count(self):
        return self.members.count()
