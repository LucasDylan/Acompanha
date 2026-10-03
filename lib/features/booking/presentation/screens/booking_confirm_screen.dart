import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/booking_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/rating_pill.dart';
import '../../data/payment_flow.dart';
import '../../providers/booking_provider.dart';
import '../widgets/payment_section.dart';

class BookingConfirmScreen extends ConsumerStatefulWidget {
  const BookingConfirmScreen({super.key, this.draft});

  final BookingDraft? draft;

  @override
  ConsumerState<BookingConfirmScreen> createState() =>
      _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends ConsumerState<BookingConfirmScreen> {
  bool _processing = false;
  String? _error;

  Future<void> _confirm() async {
    final draft = widget.draft!;
    setState(() {
      _processing = true;
      _error = null;
    });

    final repo = ref.read(bookingRepositoryProvider);
    BookingModel? booking;
    try {
      booking = await repo.createBooking(
        slotId: draft.slot.id,
        hostId: draft.host.id,
      );
      final outcome = await ref.read(paymentFlowProvider).pay(booking);
      if (outcome == PaymentOutcome.cancelled) {
        // Free the time again right away instead of holding it unpaid.
        await repo.cancelBooking(booking.id);
        _finishWithError('Pagamento cancelado. O horário continua livre.');
        return;
      }
      ref.invalidate(myBookingsProvider);
      ref.invalidate(hostSlotsProvider(draft.host.id));
      if (!mounted) return;
      context.go('/bookings');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reserva confirmada com ${draft.host.name} · ${booking.amountLabel}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (booking != null && booking.status == BookingStatus.pending) {
        // Payment failed after the booking was made: release the slot.
        try {
          await repo.cancelBooking(booking.id);
        } catch (_) {}
      }
      ref.invalidate(hostSlotsProvider(draft.host.id));
      _finishWithError(e.toString());
    }
  }

  void _finishWithError(String message) {
    if (!mounted) return;
    setState(() {
      _processing = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final t = Theme.of(context).textTheme;

    if (draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirmar reserva')),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Dados da reserva ausentes',
          message: 'Escolha um horário novamente.',
          tone: EmptyStateTone.error,
          actionLabel: 'Voltar',
          onAction: () => context.pop(),
        ),
      );
    }

    final host = draft.host;
    final slot = draft.slot;
    final amount = slot.priceFor(host.pricePerHour ?? 0);
    final config = ref.watch(_paymentConfigProvider).valueOrNull;
    final testMode = config?.unpaidBookingsAllowed ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar reserva'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _processing ? null : () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x20,
          AppSpacing.x16,
          AppSpacing.x20,
          AppSpacing.x24,
        ),
        children: [
          Text('Revise e confirme',
              style: t.labelMedium?.copyWith(color: AppColors.brand600)),
          const SizedBox(height: AppSpacing.x12),
          AppCard(
            child: Row(
              children: [
                AppAvatar(url: host.avatarUrl, name: host.name, radius: 28),
                const SizedBox(width: AppSpacing.x16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(host.name, style: t.titleLarge),
                      if (host.location != null) ...[
                        const SizedBox(height: AppSpacing.x2),
                        Text(host.location!, style: t.bodyMedium),
                      ],
                    ],
                  ),
                ),
                if (host.rating != null && host.reviewCount > 0)
                  RatingPill(rating: host.rating!, reviewCount: host.reviewCount),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x16),
          AppCard(
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.event_rounded,
                  label: 'Data',
                  value: formatDayMonth(slot.startAt),
                ),
                const Divider(height: AppSpacing.x24),
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Horário',
                  value: slot.timeLabel,
                ),
                const Divider(height: AppSpacing.x24),
                _DetailRow(
                  icon: Icons.hourglass_empty_rounded,
                  label: 'Duração',
                  value: formatDuration(slot.durationMinutes),
                ),
                if (host.pricePerHour != null) ...[
                  const Divider(height: AppSpacing.x24),
                  _DetailRow(
                    icon: Icons.payments_outlined,
                    label: 'Valor por hora',
                    value: formatMoney(host.pricePerHour!, host.currency),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x16),
          AppCard(
            color: AppColors.successBg,
            shadow: false,
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: AppColors.success, size: 20),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: Text(
                    'Cancelamento com reembolso até '
                    '${AppConstants.freeCancellationHours}h antes do encontro.',
                    style: t.bodyMedium?.copyWith(color: AppColors.ink700),
                  ),
                ),
              ],
            ),
          ),
          if (testMode) ...[
            const SizedBox(height: AppSpacing.x12),
            AppCard(
              color: AppColors.warningBg,
              shadow: false,
              child: Row(
                children: [
                  const Icon(Icons.science_outlined,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: AppSpacing.x12),
                  Expanded(
                    child: Text(
                      'Modo de teste: o servidor está sem pagamentos '
                      'configurados, então a reserva é confirmada sem cobrança.',
                      style: t.bodyMedium?.copyWith(color: AppColors.ink700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.x16),
            AppCard(
              color: AppColors.errorBg,
              shadow: false,
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: AppSpacing.x12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: t.bodyMedium?.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: PaymentSection(
        amount: amount,
        currency: host.currency,
        onPayPressed: _processing ? null : _confirm,
        isLoading: _processing,
        charges: !testMode && amount > 0,
      ),
    );
  }
}

final _paymentConfigProvider = FutureProvider.autoDispose(
  (ref) => ref.read(bookingRepositoryProvider).getPaymentConfig(),
);

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.ink100,
            borderRadius: AppRadius.brSm,
          ),
          child: Icon(icon, size: 20, color: AppColors.ink700),
        ),
        const SizedBox(width: AppSpacing.x12),
        Text(label, style: t.bodyMedium),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
          child: Text(value, style: t.titleSmall, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
