import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../widgets/register_form.dart';

class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

  static const name = 'register';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x24,
            vertical: AppSpacing.x8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Crie sua\nconta', style: t.displaySmall),
              const SizedBox(height: AppSpacing.x8),
              Text(
                'Faça parte de uma comunidade de conexões reais.',
                style: t.bodyLarge?.copyWith(color: AppColors.ink500),
              ),
              const SizedBox(height: AppSpacing.x32),
              const RegisterForm(),
              const SizedBox(height: AppSpacing.x24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Já tem uma conta? ', style: t.bodyMedium),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      'Entrar',
                      style: t.labelLarge?.copyWith(color: AppColors.brand600),
                    ),
                  ),
                ],
              ),
            ],
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),
        ),
      ),
    );
  }
}
