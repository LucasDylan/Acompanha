import 'package:flutter/animation.dart';

/// Motion tokens. Consistent, slightly-eased timings make the app feel
/// "designed" rather than using random Durations per call site.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration page = Duration(milliseconds: 350);

  /// Standard easing for entrances/UI — soft, premium deceleration.
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}
