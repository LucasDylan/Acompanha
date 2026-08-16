import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles the Material 3 [ThemeData] for GymBuddy — dark-first design.
///
/// Screens should rarely need explicit styling. Buttons, inputs, cards,
/// chips, nav — all get their premium dark look from here so the UI stays
/// consistent by default.
class AppTheme {
  AppTheme._();

  // Kept for backward-compatible references elsewhere in the codebase.
  static const Color primary = AppColors.brand;

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      primaryContainer: AppColors.brand700,
      onPrimaryContainer: AppColors.brand100,
      secondary: AppColors.accent,
      onSecondary: Colors.black,
      surface: AppColors.surface,
      onSurface: AppColors.ink900,
      onSurfaceVariant: AppColors.ink600,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.ink50,
      surfaceContainer: AppColors.ink100,
      outline: AppColors.ink300,
      outlineVariant: AppColors.ink200,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorBg,
    );

    final textTheme = AppType.textTheme(AppColors.ink900, AppColors.ink500);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink900,
        titleTextStyle: textTheme.headlineSmall,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Primary CTA — tall, pill, orange gradient feel.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.ink200,
          disabledForegroundColor: AppColors.ink500,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink900,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: AppColors.ink300, width: 1.5),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand400,
          textStyle: textTheme.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.ink100,
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.ink400),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
        floatingLabelStyle:
            textTheme.labelMedium?.copyWith(color: AppColors.brand400),
        prefixIconColor: AppColors.ink500,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x16,
          vertical: AppSpacing.x16,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: const BorderSide(color: AppColors.ink200, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: AppColors.brand, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.ink100,
        selectedColor: AppColors.brand,
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium!,
        secondaryLabelStyle:
            textTheme.labelMedium!.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x12,
          vertical: AppSpacing.x8,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brPill),
        showCheckmark: false,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.ink200,
        thickness: 1,
        space: 1,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.ink300,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brand.withValues(alpha: 0.2),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.brand : AppColors.ink500,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall!.copyWith(
            letterSpacing: 0,
            color: selected ? AppColors.brand : AppColors.ink500,
          );
        }),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink100,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.ink900),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        insetPadding: const EdgeInsets.all(AppSpacing.x16),
      ),
    );
  }

  // Keep 'light' as alias to dark for now — GymBuddy is dark-only.
  static ThemeData get light => dark;
}
