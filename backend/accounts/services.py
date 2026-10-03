from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken


def revoke_all_sessions(user):
    """Blacklist every refresh token the user holds, logging out all devices."""
    for token in OutstandingToken.objects.filter(user=user):
        BlacklistedToken.objects.get_or_create(token=token)


def delete_account(user):
    """Close the account for good.

    Other people's records (their bookings, payments, chats) still point at
    this user, so the row stays — but everything that identifies the person is
    wiped and the account can never log in again.
    """
    from bookings.models import Booking
    from bookings.services import BookingError, cancel_booking
    from matches.models import MatchRequest
    from profiles.models import Slot

    # Upcoming meetings are called off first, refunding clients per policy.
    upcoming = Booking.objects.filter(
        Q(client=user) | Q(host__user=user),
        status__in=[Booking.STATUS_PENDING, Booking.STATUS_CONFIRMED],
        slot__start_at__gt=timezone.now(),
    )
    for booking in upcoming:
        try:
            cancel_booking(booking.pk, user)
        except BookingError:
            pass  # Already settled or started; nothing left to cancel.

    with transaction.atomic():
        profile = getattr(user, 'host_profile', None)
        if profile is not None:
            profile.is_active = False
            profile.bio = ''
            profile.display_name = 'Conta excluída'
            profile.save(update_fields=['is_active', 'bio', 'display_name', 'updated_at'])
            profile.slots.filter(status=Slot.STATUS_AVAILABLE).delete()
            for photo in profile.photos.all():
                photo.photo.delete(save=False)
                photo.delete()

        for photo in user.profile_photos.all():
            photo.photo.delete(save=False)
            photo.delete()
        MatchRequest.objects.filter(sender=user).delete()
        MatchRequest.objects.filter(receiver=user).delete()

        if user.avatar:
            user.avatar.delete(save=False)
        placeholder = f'deleted-{user.pk}@deleted.invalid'
        user.username = placeholder
        user.email = placeholder
        user.first_name = ''
        user.last_name = ''
        user.display_name = 'Conta excluída'
        user.avatar = None
        user.avatar_url = ''
        user.facebook_id = None
        user.bio = ''
        user.age = None
        user.gym = None
        user.workout_types = []
        user.available_days = []
        user.is_active = False
        user.set_unusable_password()
        user.save()
        revoke_all_sessions(user)
