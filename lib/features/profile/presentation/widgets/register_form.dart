import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/providers/auth_provider.dart';

class RegisterForm extends ConsumerStatefulWidget {
  const RegisterForm({super.key});

  @override
  ConsumerState<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authStateProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : null,
        );

    if (!mounted) return;
    ref.read(authStateProvider).whenOrNull(
      data: (user) {
        if (user != null) context.go('/');
      },
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nome de exibição',
              hintText: 'Como as pessoas vão te ver',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.x16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              hintText: 'voce@exemplo.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Digite seu e-mail';
              if (!v.contains('@')) return 'Digite um e-mail válido';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.x16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Senha',
              helperText: 'Mínimo de 6 caracteres',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Digite uma senha';
              if (v.length < 6) return 'Mínimo de 6 caracteres';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.x24),
          AppButton(
            label: 'Criar conta',
            glow: true,
            isLoading: authState.isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.x16),
          Text(
            'Ao continuar, você concorda com os Termos e a Política de Privacidade.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.ink400),
          ),
        ],
      ),
    );
  }
}
