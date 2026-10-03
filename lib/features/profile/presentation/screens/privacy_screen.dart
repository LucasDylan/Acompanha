import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/providers/auth_provider.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _deleting = false;

  static const _points = [
    (
      Icons.visibility_outlined,
      'O que os outros veem',
      'Seu nome, foto, academia, nível e treinos. Seu e-mail nunca é mostrado '
          'para outras pessoas.',
    ),
    (
      Icons.lock_outline_rounded,
      'Pagamentos',
      'Os dados do cartão vão direto para o Stripe, nosso processador de '
          'pagamentos. O Acompanha não armazena números de cartão.',
    ),
    (
      Icons.chat_bubble_outline_rounded,
      'Mensagens',
      'Só dá para conversar com quem você tem uma reserva ou com parceiros que '
          'aceitaram seu pedido.',
    ),
    (
      Icons.location_on_outlined,
      'Localização',
      'Usada só quando você liga "Perto de mim" na busca, para ordenar por '
          'distância. Não é salva no servidor.',
    ),
  ];

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir sua conta?'),
        content: const Text(
          'Isso é permanente. Seus dados pessoais e fotos são apagados, seu '
          'anúncio sai do ar e suas próximas reservas são canceladas (com '
          'reembolso conforme a política de cancelamento). Você não poderá mais '
          'entrar com esta conta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir conta'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      // The router takes the user to the login screen once the session ends.
      await ref.read(authStateProvider.notifier).deleteAccount();
      messenger.showSnackBar(
        const SnackBar(content: Text('Sua conta foi excluída.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade e segurança')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.x20),
        children: [
          for (final (icon, title, body) in _points) ...[
            AppCard(
              border: true,
              shadow: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: AppColors.brand600),
                  const SizedBox(width: AppSpacing.x12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.titleSmall),
                        const SizedBox(height: AppSpacing.x4),
                        Text(body, style: t.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x12),
          ],
          const SizedBox(height: AppSpacing.x12),
          Text(
            'Dúvidas sobre seus dados: ${AppConstants.supportEmail}',
            style: t.bodySmall?.copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.x32),
          OutlinedButton.icon(
            onPressed: _deleting ? null : _deleteAccount,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(52),
            ),
            icon: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_outlined),
            label: const Text('Excluir minha conta'),
          ),
        ],
      ),
    );
  }
}
