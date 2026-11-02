import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/links.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../providers/payouts_provider.dart';

/// Where the host sets up (and later checks) how they get paid. Hidden while
/// the server runs without real payments.
class PayoutsCard extends ConsumerStatefulWidget {
  const PayoutsCard({super.key});

  @override
  ConsumerState<PayoutsCard> createState() => _PayoutsCardState();
}

class _PayoutsCardState extends ConsumerState<PayoutsCard> {
  // Stripe's sign-up happens in the browser; check again on the way back.
  late final AppLifecycleListener _lifecycle;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(payoutStatusProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _open(Future<String> Function() link) async {
    setState(() => _opening = true);
    try {
      final url = await link();
      if (mounted) {
        await openLink(context, url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(payoutStatusProvider).valueOrNull;
    if (status == null || !status.needed) return const SizedBox.shrink();

    final t = Theme.of(context).textTheme;
    final repo = ref.read(payoutsRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x12),
      child: AppCard(
        border: true,
        shadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  status.ready
                      ? Icons.check_circle_rounded
                      : Icons.account_balance_outlined,
                  color: status.ready ? AppColors.success : AppColors.brand,
                ),
                const SizedBox(width: AppSpacing.x8),
                Expanded(
                  child: Text(
                    status.ready
                        ? 'Recebimentos ativos'
                        : 'Configure seus recebimentos',
                    style: t.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x8),
            Text(
              status.ready
                  ? 'O valor das reservas cai na sua conta pelo Stripe, já '
                      'descontados os ${status.feeLabel} do Acompanha.'
                  : 'Seu anúncio só aparece na busca depois disso. O cadastro é '
                      'feito no Stripe, nosso parceiro de pagamentos, e pede '
                      'seus dados e uma conta bancária. O Acompanha fica com '
                      '${status.feeLabel} de cada reserva.',
              style: t.bodyMedium?.copyWith(color: AppColors.ink600),
            ),
            const SizedBox(height: AppSpacing.x12),
            if (status.ready)
              AppButton.secondary(
                label: 'Ver meus recebimentos',
                isLoading: _opening,
                onPressed: () => _open(repo.dashboardUrl),
              )
            else
              AppButton(
                label: status.connected
                    ? 'Continuar cadastro'
                    : 'Configurar recebimentos',
                isLoading: _opening,
                onPressed: () => _open(repo.onboardingUrl),
              ),
          ],
        ),
      ),
    );
  }
}
