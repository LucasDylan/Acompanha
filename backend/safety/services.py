"""What blocking someone changes, and how reports reach the moderators."""
from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction
from django.db.models import Q
from django.utils import timezone

from .models import Block, Report


@transaction.atomic
def block_user(blocker, blocked):
    from bookings.models import TrainingSession
    from matches.models import MatchRequest

    block, _ = Block.objects.get_or_create(blocker=blocker, blocked=blocked)
    # They stop being gym partners (pending requests go too)...
    MatchRequest.objects.filter(
        Q(sender=blocker, receiver=blocked) | Q(sender=blocked, receiver=blocker),
    ).delete()
    # ...and training they had planned together is called off. Paid bookings
    # are left alone: cancelling them follows the refund policy, in Reservas.
    TrainingSession.objects.filter(
        Q(initiator=blocker, partner=blocked) | Q(initiator=blocked, partner=blocker),
        status__in=[TrainingSession.STATUS_PENDING, TrainingSession.STATUS_CONFIRMED],
        scheduled_at__gt=timezone.now(),
    ).update(status=TrainingSession.STATUS_CANCELLED)
    return block


def unblock_user(blocker, blocked_id):
    Block.objects.filter(blocker=blocker, blocked_id=blocked_id).delete()


def report_user(reporter, reported, reason, details='', conversation=None):
    report = Report.objects.create(
        reporter=reporter,
        reported=reported,
        reason=reason,
        details=details,
        conversation=conversation,
    )
    _notify_moderators(report)
    return report


def _notify_moderators(report):
    # The stores expect reports to be acted on quickly, so someone gets an
    # e-mail for each one (MODERATION_EMAIL); the queue lives in the admin.
    if not settings.MODERATION_EMAIL:
        return
    reported = report.reported
    send_mail(
        subject=f'[Acompanha] Denúncia #{report.pk}: {report.get_reason_display()}',
        message=(
            f'Denunciado: {reported.display_name or "—"} <{reported.email}> (id {reported.pk})\n'
            f'Por: {report.reporter.email if report.reporter else "—"}\n'
            f'Motivo: {report.get_reason_display()}\n'
            f'Detalhes: {report.details or "—"}\n\n'
            f'Analise em /admin/safety/report/{report.pk}/change/'
        ),
        from_email=None,
        recipient_list=[settings.MODERATION_EMAIL],
        fail_silently=True,
    )
