import 'package:flutter/material.dart';

import '../../../../core/constants/fitness.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../matches/models/gym_member_model.dart';

/// Gym-mate card — photo, name, level, workouts and the "train together" action.
class PartnerCard extends StatelessWidget {
  const PartnerCard({
    super.key,
    required this.member,
    required this.onTap,
    required this.onAction,
    this.busy = false,
  });

  final GymMemberModel member;
  final VoidCallback onTap;

  /// Send / accept the request, or open the chat once matched.
  final VoidCallback onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.brXl,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brXl,
        child: Material(
          color: AppColors.surface,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(
                        url: member.avatarUrl,
                        seed: member.name,
                        initial: member.name[0],
                      ),
                      const DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: AppColors.photoScrim),
                      ),
                      Positioned(
                        top: AppSpacing.x16,
                        left: AppSpacing.x16,
                        child: FitnessLevelBadge(level: member.fitnessLevel),
                      ),
                      Positioned(
                        left: AppSpacing.x20,
                        right: AppSpacing.x20,
                        bottom: AppSpacing.x20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.age == null
                                  ? member.name
                                  : '${member.name}, ${member.age}',
                              style: t.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (member.bio != null) ...[
                              const SizedBox(height: AppSpacing.x4),
                              Text(
                                member.bio!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.x6,
                          runSpacing: AppSpacing.x6,
                          children: member.workoutTypes
                              .take(3)
                              .map((c) => _WorkoutTypeChip(label: c))
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x12),
                      _ActionButton(
                        status: member.matchStatus,
                        busy: busy,
                        onTap: onAction,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FitnessLevelBadge extends StatelessWidget {
  const FitnessLevelBadge({super.key, required this.level});

  final String? level;

  Color get _color => switch (level) {
        'advanced' => AppColors.brand,
        'intermediate' => AppColors.accent,
        _ => AppColors.info,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x10,
        vertical: AppSpacing.x4,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.85),
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        Fitness.levelLabel(level),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _WorkoutTypeChip extends StatelessWidget {
  const _WorkoutTypeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x8,
        vertical: AppSpacing.x4,
      ),
      decoration: BoxDecoration(
        color: AppColors.ink100,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: AppColors.ink200),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.ink700,
            ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.status,
    required this.onTap,
    required this.busy,
  });

  final MatchStatus status;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final (label, icon, filled) = switch (status) {
      MatchStatus.none => ('Treinar', Icons.fitness_center_rounded, true),
      MatchStatus.received => ('Aceitar', Icons.check_rounded, true),
      MatchStatus.sent => ('Enviado', Icons.schedule_rounded, false),
      MatchStatus.matched => ('Mensagem', Icons.chat_bubble_outline_rounded, false),
    };
    final enabled = !busy && status != MatchStatus.sent;
    final fg = filled ? Colors.white : AppColors.ink600;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x16,
          vertical: AppSpacing.x10,
        ),
        decoration: BoxDecoration(
          gradient: filled ? AppColors.brandGradient : null,
          color: filled ? null : AppColors.ink100,
          borderRadius: AppRadius.brPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            else
              Icon(icon, color: fg, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
