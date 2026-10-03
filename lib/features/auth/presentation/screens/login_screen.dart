import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../widgets/login_form.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background accent blobs
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.brand.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x24,
                vertical: AppSpacing.x32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.x16),
                  const _BrandMark(),
                  const SizedBox(height: AppSpacing.x40),
                  Text(
                    'Bem-vindo de volta 👋',
                    style: t.displaySmall?.copyWith(color: AppColors.ink900),
                  ),
                  const SizedBox(height: AppSpacing.x8),
                  Text(
                    'Entre para marcar encontros e achar parceiros de treino.',
                    style: t.bodyLarge?.copyWith(color: AppColors.ink500),
                  ),
                  const SizedBox(height: AppSpacing.x32),
                  const LoginForm(),
                  const SizedBox(height: AppSpacing.x24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Novo por aqui? ',
                        style: t.bodyMedium?.copyWith(color: AppColors.ink500),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: Text(
                          'Criar uma conta',
                          style: t.labelLarge?.copyWith(color: AppColors.brand400),
                        ),
                      ),
                    ],
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: AppRadius.brLg,
            gradient: AppColors.brandGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.groups_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: AppSpacing.x12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acompanha',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.ink900,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            Text(
              'Encontros e parceiros de treino',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink500,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
