import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// The standard surface container: white, large radius, soft layered shadow,
/// optional tap. Use instead of Material `Card` so every elevated surface
/// shares the same lift and corner language.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.x16),
    this.onTap,
    this.shadow = true,
    this.border = false,
    this.radius = AppRadius.brLg,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool shadow;
  final bool border;
  final BorderRadius radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: radius,
      boxShadow: shadow ? AppShadows.sm : null,
      border: border ? Border.all(color: AppColors.ink200) : null,
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return DecoratedBox(
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: content,
        ),
      ),
    );
  }
}
