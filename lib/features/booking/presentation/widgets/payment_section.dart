import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';

/// Sticky total + confirm bar for the booking flow.
class PaymentSection extends StatelessWidget {
  const PaymentSection({
    super.key,
    required this.amount,
    required this.onPayPressed,
    this.currency = 'BRL',
    this.isLoading = false,
    this.charges = true,
  });

  final double amount;
  final String currency;
  final VoidCallback? onPayPressed;
  final bool isLoading;

  /// Whether confirming opens the card payment (false in test mode or for
  /// free sessions).
  final bool charges;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.md,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x20,
            AppSpacing.x16,
            AppSpacing.x20,
            AppSpacing.x12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (charges) ...[
                Row(
                  children: [
                    const Icon(Icons.lock_rounded,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: AppSpacing.x6),
                    Expanded(
                      child: Text(
                        'Pagamento com cartão processado pelo Stripe.',
                        style: t.bodySmall?.copyWith(color: AppColors.ink500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x12),
              ],
              Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total', style: t.bodySmall),
                      Text(formatMoney(amount, currency), style: t.titleLarge),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.x16),
                  Expanded(
                    child: AppButton(
                      label: charges ? 'Confirmar e pagar' : 'Confirmar reserva',
                      icon: charges ? Icons.lock_rounded : Icons.check_rounded,
                      glow: true,
                      isLoading: isLoading,
                      onPressed: onPayPressed,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
