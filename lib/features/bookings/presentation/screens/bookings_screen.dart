import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/booking_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../booking/providers/booking_provider.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reservas')),
      body: bookingsAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Não foi possível carregar as reservas',
          tone: EmptyStateTone.error,
          actionLabel: 'Tentar de novo',
          onAction: () => ref.invalidate(myBookingsProvider),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return EmptyState(
              icon: Icons.calendar_month_rounded,
              title: 'Nenhuma reserva ainda',
              message: 'Descubra anfitriões e marque seu primeiro encontro.',
              actionLabel: 'Explorar anfitriões',
              onAction: () => context.go('/'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x20,
              AppSpacing.x8,
              AppSpacing.x20,
              AppSpacing.x24,
            ),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
            itemBuilder: (context, index) =>
                _BookingCard(booking: bookings[index]),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                url: booking.host?.avatarUrl,
                name: booking.host?.displayName,
                radius: 26,
              ),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.host?.displayName ?? 'Anfitrião',
                        style: t.titleMedium),
                    const SizedBox(height: AppSpacing.x2),
                    Text(booking.amountLabel, style: t.bodyMedium),
                  ],
                ),
              ),
              _StatusPill(status: booking.status),
            ],
          ),
          const SizedBox(height: AppSpacing.x16),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.x12),
          Row(
            children: [
              const Icon(Icons.event_rounded, size: 16, color: AppColors.ink400),
              const SizedBox(width: AppSpacing.x8),
              Expanded(
                child: Text(
                  booking.dateTimeLabel.isEmpty
                      ? 'Horário a confirmar'
                      : booking.dateTimeLabel,
                  style: t.bodyMedium?.copyWith(color: AppColors.ink700),
                ),
              ),
              if (booking.canChat)
                TextButton.icon(
                  onPressed: () => context.push('/messages'),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Mensagem'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final BookingStatus status;

  ({String label, Color fg, Color bg}) get _style => switch (status) {
        BookingStatus.pending => (
            label: 'Pendente',
            fg: AppColors.warning,
            bg: AppColors.warningBg,
          ),
        BookingStatus.confirmed => (
            label: 'Confirmada',
            fg: AppColors.success,
            bg: AppColors.successBg,
          ),
        BookingStatus.completed => (
            label: 'Concluída',
            fg: AppColors.ink600,
            bg: AppColors.ink100,
          ),
        BookingStatus.cancelled => (
            label: 'Cancelada',
            fg: AppColors.error,
            bg: AppColors.errorBg,
          ),
        BookingStatus.disputed => (
            label: 'Em disputa',
            fg: AppColors.error,
            bg: AppColors.errorBg,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x12,
        vertical: AppSpacing.x6,
      ),
      decoration: BoxDecoration(color: s.bg, borderRadius: AppRadius.brPill),
      child: Text(
        s.label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: s.fg, letterSpacing: 0.2),
      ),
    );
  }
}
