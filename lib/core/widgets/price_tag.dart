import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Renders a price with a clear "amount / unit" hierarchy — the big number
/// reads first, the unit (`/hr`) is demoted. Used on cards, profile and the
/// booking summary so price is always presented the same way.
class PriceTag extends StatelessWidget {
  const PriceTag({
    super.key,
    required this.amount,
    this.currency = 'BRL',
    this.unit = 'h',
    this.large = false,
    this.onPhoto = false,
  });

  final double amount;
  final String currency;
  final String unit;
  final bool large;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final color = onPhoto ? Colors.white : AppColors.ink900;
    final mutedColor = onPhoto ? Colors.white70 : AppColors.ink500;
    final t = Theme.of(context).textTheme;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: formatMoney(amount, currency, compact: true),
            style: (large ? t.titleLarge : t.titleMedium)?.copyWith(color: color),
          ),
          TextSpan(
            text: ' /$unit',
            style: t.bodySmall?.copyWith(color: mutedColor),
          ),
        ],
      ),
    );
  }
}
