import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faq = [
    (
      'Como funciona uma reserva?',
      'Escolha um anfitrião em Descobrir, toque em "Ver horários", escolha um '
          'horário livre e confirme. O pagamento é feito no app com cartão e a '
          'reserva aparece em Reservas.',
    ),
    (
      'Posso cancelar?',
      'Sim. Em Reservas, toque em "Cancelar". Com pelo menos '
          '${AppConstants.freeCancellationHours}h de antecedência o valor volta '
          'para o cartão; depois disso o cancelamento não tem reembolso. Se o '
          'anfitrião cancelar, você sempre recebe o valor de volta.',
    ),
    (
      'Como falo com o anfitrião?',
      'Depois de reservar, toque em "Mensagem" na reserva. As conversas ficam '
          'na aba Mensagens.',
    ),
    (
      'Como encontro parceiros de treino?',
      'Escolha sua academia em Perfil › Minha academia. Na aba Parceiros você '
          'vê quem treina lá e pode mandar um pedido. Quando a pessoa aceitar, '
          'vocês podem conversar e marcar treinos.',
    ),
    (
      'Como viro anfitrião?',
      'Em Perfil, toque em "Criar perfil de anfitrião", defina o preço por hora '
          'e depois publique seus horários em "Gerenciar horários".',
    ),
    (
      'Esqueci minha senha',
      'Na tela de login, toque em "Esqueceu a senha?". Enviamos um código de 6 '
          'dígitos para o seu e-mail.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajuda')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.x20),
        children: [
          Text('Perguntas frequentes', style: t.titleLarge),
          const SizedBox(height: AppSpacing.x12),
          AppCard(
            padding: EdgeInsets.zero,
            // Own Material so the tiles' ink isn't painted under the card.
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (final (question, answer) in _faq)
                    ExpansionTile(
                      title: Text(question, style: t.titleSmall),
                      childrenPadding: const EdgeInsets.fromLTRB(
                        AppSpacing.x16,
                        0,
                        AppSpacing.x16,
                        AppSpacing.x16,
                      ),
                      children: [Text(answer, style: t.bodyMedium)],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x24),
          Text('Ainda precisa de ajuda?', style: t.titleLarge),
          const SizedBox(height: AppSpacing.x8),
          AppCard(
            child: Row(
              children: [
                const Icon(
                  Icons.mail_outline_rounded,
                  color: AppColors.brand600,
                ),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: SelectableText(
                    AppConstants.supportEmail,
                    style: t.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: AppConstants.supportEmail),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('E-mail copiado')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
