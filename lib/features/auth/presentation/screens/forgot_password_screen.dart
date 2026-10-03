import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../providers/auth_provider.dart';

enum _Step { email, code }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  _Step _step = _Step.email;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(_emailController.text.trim());
      if (!mounted) return;
      setState(() => _step = _Step.code);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).confirmPasswordReset(
            email: _emailController.text.trim(),
            code: _codeController.text.trim(),
            newPassword: _newPasswordController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha atualizada. Faça login.')),
      );
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _step == _Step.email
                      ? 'Esqueceu a senha?'
                      : 'Digite o código',
                  style: t.displaySmall?.copyWith(color: AppColors.ink900),
                ),
                const SizedBox(height: AppSpacing.x8),
                Text(
                  _step == _Step.email
                      ? 'Informe seu e-mail e enviaremos um código de verificação.'
                      : 'Enviamos um código para ${_emailController.text.trim()}. Digite-o abaixo com sua nova senha.',
                  style: t.bodyLarge?.copyWith(color: AppColors.ink500),
                ),
                const SizedBox(height: AppSpacing.x32),
                if (_step == _Step.email) ..._emailStepFields(),
                if (_step == _Step.code) ..._codeStepFields(),
                const SizedBox(height: AppSpacing.x16),
                AppButton(
                  label: _step == _Step.email ? 'Enviar código' : 'Redefinir senha',
                  glow: true,
                  isLoading: _loading,
                  onPressed: _step == _Step.email ? _requestCode : _confirmReset,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _emailStepFields() {
    return [
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
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
    ];
  }

  List<Widget> _codeStepFields() {
    return [
      TextFormField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(
          labelText: 'Código',
          hintText: '000000',
          prefixIcon: Icon(Icons.pin_outlined),
        ),
        validator: (v) {
          if (v == null || v.trim().length != 6) return 'Digite o código de 6 dígitos';
          return null;
        },
      ),
      const SizedBox(height: AppSpacing.x16),
      TextFormField(
        controller: _newPasswordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: 'Nova senha',
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
          if (v == null || v.isEmpty) return 'Digite a nova senha';
          if (v.length < 6) return 'Mínimo de 6 caracteres';
          return null;
        },
      ),
      const SizedBox(height: AppSpacing.x8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _loading ? null : _requestCode,
          child: const Text('Reenviar código'),
        ),
      ),
    ];
  }
}
