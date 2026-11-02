from django.contrib import admin, messages
from django.utils import timezone
from django.utils.html import format_html
from unfold.admin import ModelAdmin

from accounts.services import revoke_all_sessions

from .models import Block, Report


@admin.register(Report)
class ReportAdmin(ModelAdmin):
    list_display = ['id', 'created_at', 'reason', 'reported', 'reporter', 'status']
    list_filter = ['status', 'reason']
    search_fields = ['reported__email', 'reported__display_name', 'details']
    raw_id_fields = ['reporter', 'reported', 'conversation']
    readonly_fields = ['created_at', 'recent_messages']
    actions = ['mark_reviewed', 'suspend_reported']

    @admin.display(description='Últimas mensagens da conversa')
    def recent_messages(self, obj):
        if not obj.conversation_id:
            return '—'
        recent = obj.conversation.messages.select_related('sender').order_by('-id')[:30]
        lines = [
            f'{m.created_at:%d/%m %H:%M} {m.sender.display_name or m.sender.email}: {m.text}'
            for m in reversed(list(recent))
        ]
        return format_html('<pre style="white-space: pre-wrap">{}</pre>', '\n'.join(lines) or '—')

    @admin.action(description='Marcar como analisada')
    def mark_reviewed(self, request, queryset):
        queryset.update(status=Report.STATUS_REVIEWED, reviewed_at=timezone.now())

    @admin.action(description='Suspender a conta denunciada')
    def suspend_reported(self, request, queryset):
        suspended = 0
        for report in queryset.select_related('reported'):
            user = report.reported
            if user.is_active:
                user.is_active = False
                user.save(update_fields=['is_active'])
                profile = getattr(user, 'host_profile', None)
                if profile is not None and profile.is_active:
                    profile.is_active = False
                    profile.save(update_fields=['is_active'])
                revoke_all_sessions(user)
                suspended += 1
        queryset.update(status=Report.STATUS_REVIEWED, reviewed_at=timezone.now())
        self.message_user(request, f'{suspended} conta(s) suspensa(s).', messages.SUCCESS)


@admin.register(Block)
class BlockAdmin(ModelAdmin):
    list_display = ['id', 'blocker', 'blocked', 'created_at']
    raw_id_fields = ['blocker', 'blocked']
