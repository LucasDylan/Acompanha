import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography tokens.
///
/// Two families, paired deliberately:
///  • Plus Jakarta Sans — geometric, confident → display & headlines
///  • Inter — highly legible at small sizes → titles, body, labels
///
/// Display sizes use tight negative tracking (the single biggest lever for a
/// "premium" headline) and heavy weights.
class AppType {
  AppType._();

  static TextTheme textTheme(Color onSurface, Color muted) {
    final display = GoogleFonts.plusJakartaSans;
    final text = GoogleFonts.inter;

    return TextTheme(
      // Display — hero numbers, splash, big titles.
      displayLarge: display(
        fontSize: 40,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: onSurface,
      ),
      displayMedium: display(
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: onSurface,
      ),
      displaySmall: display(
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: onSurface,
      ),
      // Headlines — screen titles, section heroes.
      headlineMedium: display(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: onSurface,
      ),
      headlineSmall: display(
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: onSurface,
      ),
      // Titles — card headers, list items.
      titleLarge: text(
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: onSurface,
      ),
      titleMedium: text(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: onSurface,
      ),
      titleSmall: text(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      // Body.
      bodyLarge: text(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: text(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      bodySmall: text(
        fontSize: 12,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      // Labels — buttons, chips, overlines.
      labelLarge: text(
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: onSurface,
      ),
      labelMedium: text(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      labelSmall: text(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: muted,
      ),
    );
  }

  /// Uppercase overline used for small section eyebrows.
  static TextStyle overline(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall!.copyWith(
            letterSpacing: 1.2,
            color: AppColors.ink400,
          );
}
