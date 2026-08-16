import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Compact star rating. Two visual modes:
///  • `onPhoto: false` → inline amber star + value (lists, headers)
///  • `onPhoto: true`  → frosted dark pill for placing over imagery
class RatingPill extends StatelessWidget {
  const RatingPill({
    super.key,
    required this.rating,
    this.reviewCount,
    this.onPhoto = false,
  });

  final double rating;
  final int? reviewCount;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final textColor = onPhoto ? Colors.white : AppColors.ink900;
    final mutedColor = onPhoto ? Colors.white70 : AppColors.ink500;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 16, color: AppColors.rating),
        const SizedBox(width: AppSpacing.x4),
        Text(
          rating.toStringAsFixed(1),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: textColor),
        ),
        if (reviewCount != null) ...[
          const SizedBox(width: AppSpacing.x4),
          Text(
            '($reviewCount)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: mutedColor),
          ),
        ],
      ],
    );

    if (!onPhoto) return row;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x8,
        vertical: AppSpacing.x4,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: AppRadius.brPill,
      ),
      child: row,
    );
  }
}
