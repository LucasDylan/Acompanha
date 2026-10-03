import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../data/saved_account.dart';
import '../../providers/auth_provider.dart';

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authStateProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
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

  /// Gates quick-login behind Face ID/Touch ID (or device passcode as a
  /// fallback) so having the phone unlocked isn't, by itself, enough to
  /// switch into a saved account. Devices with no biometric/passcode
  /// mechanism at all (rare) fall back to allowing the login, since there's
  /// nothing to gate against.
  Future<bool> _confirmBiometric() async {
    final auth = LocalAuthentication();
    try {
      if (!await auth.isDeviceSupported()) return true;
      return await auth.authenticate(
        localizedReason: 'Confirme para entrar na sua conta',
        options: const AuthenticationOptions(biometricOnly: false),
      );
    } catch (_) {
      return true;
    }
  }

  Future<void> _submitSavedAccount(SavedAccount account) async {
    if (!await _confirmBiometric()) return;
    if (!mounted) return;
    await ref.read(authStateProvider.notifier).loginWithSavedAccount(account);

    if (!mounted) return;
    ref.read(authStateProvider).whenOrNull(
      data: (user) {
        if (user != null) context.go('/');
      },
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sessão expirada. Digite sua senha para ${account.email}.'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
        _emailController.text = account.email;
      },
    );
  }

  Future<void> _removeSavedAccount(SavedAccount account) async {
    await ref.read(authRepositoryProvider).removeSavedAccount(account.email);
    ref.invalidate(savedAccountsProvider);
  }

  Future<void> _submitFacebook() async {
    FocusScope.of(context).unfocus();
    await ref.read(authStateProvider.notifier).loginWithFacebook();

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
    final savedAccounts = ref.watch(savedAccountsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        savedAccounts.maybeWhen(
          data: (accounts) => accounts.isEmpty
              ? const SizedBox.shrink()
              : _SavedAccountsList(
                  accounts: accounts,
                  loading: authState.isLoading,
                  onTap: _submitSavedAccount,
                  onRemove: _removeSavedAccount,
                ),
          orElse: () => const SizedBox.shrink(),
        ),
        Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              if (v == null || v.isEmpty) return 'Digite sua senha';
              if (v.length < 6) return 'Mínimo de 6 caracteres';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.x8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/forgot-password'),
              child: const Text('Esqueceu a senha?'),
            ),
          ),
          const SizedBox(height: AppSpacing.x8),
          AppButton(
            label: 'Entrar',
            glow: true,
            isLoading: authState.isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.x16),
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.ink200)),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x12,
                ),
                child: Text(
                  'ou',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.ink500),
                ),
              ),
              Expanded(child: Divider(color: AppColors.ink200)),
            ],
          ),
          const SizedBox(height: AppSpacing.x16),
          OutlinedButton.icon(
            onPressed: authState.isLoading ? null : _submitFacebook,
            icon: const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2)),
            label: const Text('Continuar com Facebook'),
          ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Quick login" row of accounts that have signed in before on this device —
/// tap to sign back in without retyping the password.
class _SavedAccountsList extends StatelessWidget {
  const _SavedAccountsList({
    required this.accounts,
    required this.loading,
    required this.onTap,
    required this.onRemove,
  });

  final List<SavedAccount> accounts;
  final bool loading;
  final ValueChanged<SavedAccount> onTap;
  final ValueChanged<SavedAccount> onRemove;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contas recentes', style: t.labelLarge?.copyWith(color: AppColors.ink500)),
          const SizedBox(height: AppSpacing.x8),
          for (final account in accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x8),
              child: Opacity(
                opacity: loading ? 0.6 : 1,
                // RepaintBoundary keeps Impeller from pushing the opacity into
                // the InkWell's ripple paint, which it can't accept and crashes on iOS.
                child: RepaintBoundary(
                child: Material(
                  color: AppColors.ink100,
                  borderRadius: AppRadius.brMd,
                  child: InkWell(
                    borderRadius: AppRadius.brMd,
                    onTap: loading ? null : () => onTap(account),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x12,
                        vertical: AppSpacing.x8,
                      ),
                      child: Row(
                        children: [
                          AppAvatar(
                            url: account.avatarUrl,
                            name: account.displayName ?? account.email,
                            radius: 18,
                          ),
                          const SizedBox(width: AppSpacing.x12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (account.displayName != null &&
                                    account.displayName!.isNotEmpty)
                                  Text(account.displayName!, style: t.bodyMedium),
                                Text(
                                  account.email,
                                  style: t.bodySmall?.copyWith(color: AppColors.ink500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            iconSize: 18,
                            icon: const Icon(Icons.close_rounded, color: AppColors.ink400),
                            onPressed: loading ? null : () => onRemove(account),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.x12),
        ],
      ),
    );
  }
}
