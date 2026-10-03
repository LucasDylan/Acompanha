import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../providers/auth_provider.dart';

/// Shown while the saved session is restored at startup. The router moves on
/// by itself once that finishes; if the server can't be reached, this offers
/// a retry instead of silently logging the user out.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    borderRadius: AppRadius.brLg,
                    gradient: AppColors.brandGradient,
                  ),
                  child: const Icon(Icons.groups_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: AppSpacing.x16),
                Text('Acompanha', style: t.headlineSmall),
                const SizedBox(height: AppSpacing.x32),
                if (auth.hasError) ...[
                  Text(
                    auth.error.toString(),
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(color: AppColors.ink500),
                  ),
                  const SizedBox(height: AppSpacing.x20),
                  AppButton(
                    label: 'Tentar de novo',
                    expand: false,
                    onPressed: () =>
                        ref.read(authStateProvider.notifier).retry(),
                  ),
                ] else
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
