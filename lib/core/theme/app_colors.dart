import 'package:flutter/material.dart';

/// Color tokens for GymBuddy — dark-first, energetic gym aesthetic.
///
/// Primary: electric orange (#FF5722) — motivation, energy, action.
/// Accent: lime green (#CCFF00) — results, vitality, progress.
/// Surface: deep charcoal ramp — premium dark mode feel.
/// Never use raw [Colors] directly in screens — always go through these tokens
/// or the semantic roles on [Theme.of(context).colorScheme].
class AppColors {
  AppColors._();

  // ── Brand (electric orange) ──────────────────────────────────────────────
  static const Color brand50  = Color(0xFFFFF3E0);
  static const Color brand100 = Color(0xFFFFE0B2);
  static const Color brand200 = Color(0xFFFFCC80);
  static const Color brand300 = Color(0xFFFFB74D);
  static const Color brand400 = Color(0xFFFFA726);
  static const Color brand500 = Color(0xFFFF5722); // primary
  static const Color brand600 = Color(0xFFE64A19);
  static const Color brand700 = Color(0xFFBF360C);

  static const Color brand      = brand500;
  static const Color brandStrong = brand600;

  // ── Accent (lime / neon green) ───────────────────────────────────────────
  static const Color accent    = Color(0xFFCCFF00);
  static const Color accentDim = Color(0xFF8BC34A);

  // ── Dark surfaces (charcoal ramp) ────────────────────────────────────────
  static const Color ink900 = Color(0xFFF5F5F5); // primary text (on dark)
  static const Color ink800 = Color(0xFFE0E0E0);
  static const Color ink700 = Color(0xFFBDBDBD);
  static const Color ink600 = Color(0xFF9E9E9E);
  static const Color ink500 = Color(0xFF757575); // secondary text
  static const Color ink400 = Color(0xFF616161); // tertiary / hint
  static const Color ink300 = Color(0xFF424242); // borders
  static const Color ink200 = Color(0xFF2C2C2C); // dividers
  static const Color ink100 = Color(0xFF212121); // fills
  static const Color ink50  = Color(0xFF1A1A1A); // card surface

  static const Color surface    = Color(0xFF1E1E1E); // card/sheet bg
  static const Color background = Color(0xFF121212); // app background

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success   = Color(0xFF66BB6A);
  static const Color successBg = Color(0xFF1B5E20);
  static const Color warning   = Color(0xFFFFA726);
  static const Color warningBg = Color(0xFF4E2600);
  static const Color error     = Color(0xFFEF5350);
  static const Color errorBg   = Color(0xFF4E1010);
  static const Color info      = Color(0xFF42A5F5);

  static const Color rating = Color(0xFFFFC107); // amber star

  // ── Avatar gradient fallbacks ─────────────────────────────────────────────
  static const List<List<Color>> avatarGradients = [
    [Color(0xFFFF5722), Color(0xFFBF360C)], // orange
    [Color(0xFFCCFF00), Color(0xFF558B2F)], // lime
    [Color(0xFF7C4DFF), Color(0xFF311B92)], // deep purple
    [Color(0xFF00BCD4), Color(0xFF006064)], // cyan
    [Color(0xFFFF4081), Color(0xFFC51162)], // pink
    [Color(0xFFFFD740), Color(0xFFFF6D00)], // amber-orange
  ];

  /// Scrim used over hero photos so white text stays legible.
  static const LinearGradient photoScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0x40000000),
      Color(0xCC000000),
    ],
    stops: [0.4, 0.65, 1.0],
  );

  /// Orange brand gradient for buttons and hero elements.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand400, brand600],
  );
}
