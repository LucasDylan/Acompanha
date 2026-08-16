import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, ghost }
enum AppButtonSize { large, medium }

/// The one button to rule them all. Consistent height, radius, typography,
/// loading state and an optional brand glow on the primary variant. Replaces
/// the ad-hoc `FilledButton`/`ElevatedButton` usage scattered across screens.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.glow = false,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.large,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  })  : variant = AppButtonVariant.secondary,
        glow = false;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  })  : variant = AppButtonVariant.ghost,
        glow = false;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final height = size == AppButtonSize.large ? 56.0 : 46.0;
    final disabled = onPressed == null || isLoading;

    final (Color bg, Color fg, BorderSide side) = switch (variant) {
      AppButtonVariant.primary => (AppColors.brand, Colors.white, BorderSide.none),
      AppButtonVariant.secondary => (
          AppColors.ink100,
          AppColors.ink900,
          BorderSide.none,
        ),
      AppButtonVariant.ghost => (
          Colors.transparent,
          AppColors.ink900,
          const BorderSide(color: AppColors.ink300, width: 1.5),
        ),
    };

    Widget child = isLoading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                Gap.h8,
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: fg),
                ),
              ),
            ],
          );

    final button = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: disabled && !isLoading ? 0.55 : 1,
      child: Material(
        color: bg,
        borderRadius: AppRadius.brMd,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: AppRadius.brMd,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x20),
            decoration: BoxDecoration(
              borderRadius: AppRadius.brMd,
              border: side == BorderSide.none ? null : Border.fromBorderSide(side),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );

    final wrapped = glow && variant == AppButtonVariant.primary && !disabled
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadius.brMd,
              boxShadow: AppShadows.brand(AppColors.brand),
            ),
            child: button,
          )
        : button;

    return expand ? SizedBox(width: double.infinity, child: wrapped) : wrapped;
  }
}
