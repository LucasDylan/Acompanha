import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A titled section with an optional trailing action ("See all"). Gives every
/// content group the same heading rhythm.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
              child: Text(
                actionLabel!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.brand600,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}
