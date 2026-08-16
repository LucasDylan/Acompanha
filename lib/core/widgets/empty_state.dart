import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Consistent empty / error state: a soft brand-tinted icon medallion, a
/// confident title, a supporting line, and an optional action. Replaces the
/// bare `Icon + Text` centers repeated across screens.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.tone = EmptyStateTone.neutral,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EmptyStateTone tone;

  @override
  Widget build(BuildContext context) {
    final accent =
        tone == EmptyStateTone.error ? AppColors.error : AppColors.brand;
    final bg = tone == EmptyStateTone.error
        ? AppColors.errorBg
        : AppColors.brand50;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: accent),
            ),
            const SizedBox(height: AppSpacing.x24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.x8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.x24),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum EmptyStateTone { neutral, error }
