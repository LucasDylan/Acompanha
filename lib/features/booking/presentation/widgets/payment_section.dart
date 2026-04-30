import 'package:flutter/material.dart';

/// Payment section - connects to Stripe for real payments.
/// For MVP, shows a "Pay" button that simulates payment.
class PaymentSection extends StatelessWidget {
  const PaymentSection({
    super.key,
    required this.amount,
    required this.onPayPressed,
    this.isLoading = false,
  });

  final double amount;
  final VoidCallback onPayPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'USD \$${amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Payment held until meeting is confirmed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isLoading ? null : onPayPressed,
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Pay & Book'),
            ),
            const SizedBox(height: 8),
            Text(
              'MVP: Payment simulation. Stripe integration ready.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
