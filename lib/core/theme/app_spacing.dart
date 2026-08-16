import 'package:flutter/widgets.dart';

/// 8pt-based spacing scale. Use these everywhere instead of magic numbers so
/// rhythm stays consistent across every screen.
class AppSpacing {
  AppSpacing._();

  static const double x2 = 2;
  static const double x4 = 4;
  static const double x6 = 6;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x20 = 20;
  static const double x24 = 24;
  static const double x32 = 32;
  static const double x40 = 40;
  static const double x48 = 48;
  static const double x64 = 64;

  /// Standard screen edge padding.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: x20);
  static const EdgeInsets screenAll = EdgeInsets.all(x20);
}

/// Corner radius tokens. Larger, softer radii read more premium than the
/// default Material 4–8px corners.
class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}

/// Vertical/horizontal whitespace as widgets — terser and more readable than
/// `const SizedBox(height: 16)` repeated everywhere.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key}) : _horizontal = false;
  const Gap.h(this.size, {super.key}) : _horizontal = true;

  final double size;
  final bool _horizontal;

  // Common presets.
  static const Widget v4 = SizedBox(height: AppSpacing.x4);
  static const Widget v8 = SizedBox(height: AppSpacing.x8);
  static const Widget v12 = SizedBox(height: AppSpacing.x12);
  static const Widget v16 = SizedBox(height: AppSpacing.x16);
  static const Widget v20 = SizedBox(height: AppSpacing.x20);
  static const Widget v24 = SizedBox(height: AppSpacing.x24);
  static const Widget v32 = SizedBox(height: AppSpacing.x32);
  static const Widget h8 = SizedBox(width: AppSpacing.x8);
  static const Widget h12 = SizedBox(width: AppSpacing.x12);
  static const Widget h16 = SizedBox(width: AppSpacing.x16);

  @override
  Widget build(BuildContext context) => _horizontal
      ? SizedBox(width: size)
      : SizedBox(height: size);
}
