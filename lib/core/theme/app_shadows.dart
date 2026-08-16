import 'package:flutter/material.dart';

/// Soft, layered shadows. Material's default single-shadow elevation looks
/// heavy; premium UIs use a tight ambient shadow plus a diffuse one to give
/// cards a gentle "lift" without a hard edge.
class AppShadows {
  AppShadows._();

  /// Resting elevation for cards.
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0D18181B), // 5% ink
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0A18181B), // 4% ink
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  /// Raised cards, sheets, sticky bars.
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x0F18181B),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x1418181B),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  /// Brand-tinted glow for the primary CTA — adds energy without a hard border.
  static List<BoxShadow> brand(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.32),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}
