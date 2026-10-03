import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../chat/providers/chat_provider.dart';
import '../../models/match_request_model.dart';
import '../../providers/matches_provider.dart';

/// Workouts scheduled with gym partners (shown under Reservas › Treinos).
class SessionsList extends ConsumerWidget {
  const SessionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final myId = ref.watch(authStateProvider).valueOrNull?.id ?? '';

    return sessions.when(
      loading: () => const AppLoading(),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não foi possível carregar os treinos',
        message: e.toString(),
        tone: EmptyStateTone.error,
        actionLabel: 'Tentar de novo',
        onAction: () => ref.invalidate(sessionsProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.fitness_center_rounded,
            title: 'Nenhum treino marcado',
            message: 'Em Parceiros › Meus parceiros, toque no calendário para '
                'convidar alguém para treinar.',
            actionLabel: 'Ir para Parceiros',
            onAction: () => context.go('/matches'),
          );
        }
        final upcoming = list
            .where((s) =>
                s.isUpcoming &&
                (s.status == SessionStatus.pending ||
                    s.status == SessionStatus.confirmed))
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        final others = list.where((s) => !upcoming.contains(s)).toList();

        return RefreshIndicator(
          onRefresh: () => ref.refresh(sessionsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.x20),
            children: [
              for (final s in upcoming) _SessionCard(session: s, myId: myId),
              if (others.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
                  child: Text('Anteriores',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                for (final s in others) _SessionCard(session: s, myId: myId),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session, required this.myId});

  final TrainingSessionModel session;
  final String myId;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action();
      ref.invalidate(sessionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final repo = ref.read(matchesRepositoryProvider);
    final other = session.other(myId);
    final invitedMe = session.partner.id == myId;
    final active = session.isUpcoming &&
        (session.status == SessionStatus.pending ||
            session.status == SessionStatus.confirmed);

    final (statusLabel, statusColor) = switch (session.status) {
      SessionStatus.pending => (
          invitedMe ? 'Convite para você' : 'Aguardando ${other.label}',
          AppColors.warning,
        ),
      SessionStatus.confirmed => ('Confirmado', AppColors.success),
      SessionStatus.completed => ('Concluído', AppColors.ink500),
      SessionStatus.cancelled => ('Cancelado', AppColors.error),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(url: other.avatarUrl, name: other.label, radius: 22),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [other.label, if (session.workoutType != null) session.workoutType!]
                            .join(' · '),
                        style: t.titleSmall,
                      ),
                      Text(
                        '${formatDayMonth(session.scheduledAt)} · '
                        '${formatTime(session.scheduledAt)} · '
                        '${formatDuration(session.durationMinutes)}',
                        style: t.bodySmall?.copyWith(color: AppColors.ink600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x8),
            Text(statusLabel,
                style: t.labelMedium?.copyWith(color: statusColor)),
            if (session.notes != null) ...[
              const SizedBox(height: AppSpacing.x4),
              Text(session.notes!, style: t.bodyMedium),
            ],
            if (active) ...[
              const Divider(height: AppSpacing.x20),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => openChatWith(context, ref, other.id),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('Mensagem'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    onPressed: () => _run(
                      context,
                      ref,
                      () => repo.cancelSession(session.id),
                      invitedMe && session.status == SessionStatus.pending
                          ? 'Convite recusado'
                          : 'Treino cancelado',
                    ),
                    child: Text(invitedMe && session.status == SessionStatus.pending
                        ? 'Recusar'
                        : 'Cancelar'),
                  ),
                  if (invitedMe && session.status == SessionStatus.pending)
                    FilledButton(
                      onPressed: () => _run(
                        context,
                        ref,
                        () => repo.confirmSession(session.id),
                        'Treino confirmado 💪',
                      ),
                      child: const Text('Aceitar'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
