import 'package:flutter/material.dart';

import '../../../../core/models/host_profile_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_network_image.dart';

/// Partner discovery card — image-first, dark, energetic gym feel.
///
/// Shows photo, name, fitness level badge, workout types, and a "Train
/// together" action button so the user can send a match request inline.
class PartnerCard extends StatelessWidget {
  const PartnerCard({
    super.key,
    required this.host,
    required this.onTap,
    this.onSendRequest,
  });

  final HostProfileModel host;
  final VoidCallback onTap;
  final VoidCallback? onSendRequest;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final categories = host.categories;
    final fitnessLevel = host.fitnessLevel ?? 'beginner';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.brXl,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
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
                // Photo hero — 4:5 portrait ratio.
                AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(
                        url: host.avatarUrl,
                        seed: host.displayName ?? host.id,
                        initial: (host.displayName?.isNotEmpty ?? false)
                            ? host.displayName![0]
                            : null,
                      ),
                      // Gradient scrim.
                      const DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: AppColors.photoScrim),
                      ),
                      // Fitness level badge (top-left).
                      Positioned(
                        top: AppSpacing.x16,
                        left: AppSpacing.x16,
                        child: _FitnessLevelBadge(level: fitnessLevel),
                      ),
                      // Name + location (bottom-left).
                      Positioned(
                        left: AppSpacing.x20,
                        right: AppSpacing.x20,
                        bottom: AppSpacing.x20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              host.displayName ?? 'Parceiro',
                              style: t.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (host.bio != null && host.bio!.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.x4),
                              Text(
                                host.bio!,
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

                // Bottom info strip.
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  child: Row(
                    children: [
                      // Workout type chips.
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.x6,
                          runSpacing: AppSpacing.x6,
                          children: categories
                              .take(3)
                              .map((c) => _WorkoutTypeChip(label: c))
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x12),
                      // Train together CTA.
                      _TrainButton(onTap: onSendRequest),
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

class _FitnessLevelBadge extends StatelessWidget {
  const _FitnessLevelBadge({required this.level});

  final String level;

  Color get _color {
    switch (level) {
      case 'advanced':
        return AppColors.brand;
      case 'intermediate':
        return AppColors.accent;
      default:
        return AppColors.info;
    }
  }

  String get _label {
    switch (level) {
      case 'advanced':
        return '🔥 Avançado';
      case 'intermediate':
        return '⚡ Intermediário';
      default:
        return '🌱 Iniciante';
    }
  }

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
        _label,
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

class _TrainButton extends StatefulWidget {
  const _TrainButton({this.onTap});
  final VoidCallback? onTap;

  @override
  State<_TrainButton> createState() => _TrainButtonState();
}

class _TrainButtonState extends State<_TrainButton> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _sent
          ? null
          : () {
              setState(() => _sent = true);
              widget.onTap?.call();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x16,
          vertical: AppSpacing.x10,
        ),
        decoration: BoxDecoration(
          gradient: _sent ? null : AppColors.brandGradient,
          color: _sent ? AppColors.ink200 : null,
          borderRadius: AppRadius.brPill,
          boxShadow: _sent
              ? null
              : [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _sent ? Icons.check_rounded : Icons.fitness_center_rounded,
              color: _sent ? AppColors.ink500 : Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              _sent ? 'Enviado' : 'Treinar',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _sent ? AppColors.ink500 : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// Re-export so old imports of GlassChip still resolve.
class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x10,
        vertical: AppSpacing.x4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: Colors.white30),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
