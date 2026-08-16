import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

/// Sticky payment bar for the booking flow.
///
/// Fintech-grade: a clear total, a trust line ("held securely…"), and a single
/// confident CTA. No debug/MVP copy — this is the screen investors see.
class PaymentSection extends StatelessWidget {
  const PaymentSection({
    super.key,
    required this.amount,
    required this.onPayPressed,
    this.currency = 'USD',
    this.isLoading = false,
  });

  final double amount;
  final String currency;
  final VoidCallback onPayPressed;
  final bool isLoading;

  String get _symbol => switch (currency.toUpperCase()) {
        'USD' => '\$',
        'BRL' => 'R\$',
        'EUR' => '€',
        'GBP' => '£',
        _ => '$currency ',
      };

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
              Row(
                children: [
                  const Icon(Icons.lock_rounded,
                      size: 14, color: AppColors.success),
                  const SizedBox(width: AppSpacing.x6),
                  Expanded(
                    child: Text(
                      'Retido com segurança — liberado só após o encontro ser confirmado.',
                      style: t.bodySmall?.copyWith(color: AppColors.ink500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x12),
              Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total', style: t.bodySmall),
                      Text(
                        '$_symbol${amount.toStringAsFixed(2)}',
                        style: t.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.x16),
                  Expanded(
                    child: AppButton(
                      label: 'Confirmar e pagar',
                      icon: Icons.lock_rounded,
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
