import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Pill used both as a read-only tag (on cards/profiles) and as a selectable
/// filter (on Discovery). Selected state uses the brand fill; unselected uses
/// a soft neutral fill with no border — calmer than Material's default `Chip`.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink700;
    final bg = selected ? AppColors.brand : AppColors.ink100;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: compact ? 13 : 15, color: fg),
          const SizedBox(width: AppSpacing.x6),
        ],
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fg,
                fontSize: compact ? 12 : 13,
              ),
        ),
      ],
    );

    final padding = EdgeInsets.symmetric(
      horizontal: compact ? AppSpacing.x12 : AppSpacing.x16,
      vertical: compact ? AppSpacing.x6 : AppSpacing.x8,
    );

    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.brPill),
        child: content,
      );
    }

    return Material(
      color: bg,
      borderRadius: AppRadius.brPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brPill,
        child: Padding(padding: padding, child: content),
      ),
    );
  }
}

/// Frosted variant for use directly on top of photos (e.g. category tag on a
/// host card image).
class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x12,
        vertical: AppSpacing.x6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: AppSpacing.x4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}
