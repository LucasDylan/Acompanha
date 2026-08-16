import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/host_profile_model.dart';
import '../../../../core/models/slot_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/rating_pill.dart';
import '../../../discovery/providers/discovery_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../providers/booking_provider.dart';
import '../widgets/payment_section.dart';

class BookingConfirmScreen extends ConsumerStatefulWidget {
  const BookingConfirmScreen({super.key, required this.hostId, this.slot});

  final String hostId;
  final SlotModel? slot;

  static const name = 'booking_confirm';

  @override
  ConsumerState<BookingConfirmScreen> createState() =>
      _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends ConsumerState<BookingConfirmScreen> {
  bool _isProcessing = false;
  String? _error;

  HostProfileModel? _resolveHost() {
    final list = ref.read(discoveryHostsProvider).valueOrNull;
    if (list != null) {
      for (final h in list) {
        if (h.id == widget.hostId) return h;
      }
    }
    return ref.read(hostProfileProvider(widget.hostId)).valueOrNull;
  }

  Future<void> _confirmBooking() async {
    final slot = widget.slot;
    final host = _resolveHost();
    if (slot == null || widget.hostId.isEmpty || host == null) {
      setState(() => _error = 'Algo deu errado com esta reserva.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final repo = ref.read(bookingRepositoryProvider);
      final booking =
          await repo.createBooking(slotId: slot.id, hostId: widget.hostId);
      ref.invalidate(myBookingsProvider);

      if (!mounted) return;
      context.go('/bookings');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reserva confirmada · ${booking.amountLabel}')),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Não foi possível concluir sua reserva. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final host = _resolveHost();
    final t = Theme.of(context).textTheme;

    if (slot == null || host == null) {
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

    final amount = host.pricePerHour ?? 0;
    final minutes = slot.endAt.difference(slot.startAt).inMinutes;
    final durationLabel = minutes % 60 == 0
        ? '${minutes ~/ 60}h de sessão'
        : '$minutes min de sessão';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar reserva'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
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

          // Host summary.
          AppCard(
            child: Row(
              children: [
                AppAvatar(url: host.avatarUrl, name: host.displayName, radius: 28),
                const SizedBox(width: AppSpacing.x16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(host.displayName ?? 'Anfitrião', style: t.titleLarge),
                      if (host.location != null) ...[
                        const SizedBox(height: AppSpacing.x2),
                        Text(host.location!, style: t.bodyMedium),
                      ],
                    ],
                  ),
                ),
                if (host.rating != null)
                  RatingPill(rating: host.rating!, reviewCount: host.reviewCount),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x16),

          // Session details.
          AppCard(
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.event_rounded,
                  label: 'Data',
                  value: slot.dateLabel,
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
                  value: durationLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x16),

          // Reassurance.
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
                    'Cancelamento grátis até 24h antes do encontro.',
                    style: t.bodyMedium?.copyWith(color: AppColors.ink700),
                  ),
                ),
              ],
            ),
          ),

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
        onPayPressed: _confirmBooking,
        isLoading: _isProcessing,
      ),
    );
  }
}

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
        const Spacer(),
        Text(value, style: t.titleSmall),
      ],
    );
  }
}
