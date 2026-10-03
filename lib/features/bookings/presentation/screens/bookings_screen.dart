import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/booking_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../booking/data/payment_flow.dart';
import '../../../booking/providers/booking_provider.dart';
import '../../../chat/providers/chat_provider.dart';
import '../../../matches/presentation/widgets/sessions_list.dart';
import '../widgets/review_sheet.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHost = ref.watch(authStateProvider).valueOrNull?.isHost ?? false;
    final tabs = [
      const Tab(text: 'Minhas reservas'),
      if (isHost) const Tab(text: 'Recebidas'),
      const Tab(text: 'Treinos'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reservas'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs,
          ),
        ),
        body: TabBarView(
          children: [
            const _BookingsTab(asHost: false),
            if (isHost) const _BookingsTab(asHost: true),
            const SessionsList(),
          ],
        ),
      ),
    );
  }
}

class _BookingsTab extends ConsumerWidget {
  const _BookingsTab({required this.asHost});

  final bool asHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = asHost ? receivedBookingsProvider : myBookingsProvider;
    final bookingsAsync = ref.watch(provider);

    return bookingsAsync.when(
      loading: () => const AppLoading(),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não foi possível carregar as reservas',
        message: e.toString(),
        tone: EmptyStateTone.error,
        actionLabel: 'Tentar de novo',
        onAction: () => ref.invalidate(provider),
      ),
      data: (bookings) {
        if (bookings.isEmpty) {
          return asHost
              ? EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Nenhuma reserva recebida',
                  message: 'Publique horários para as pessoas poderem reservar.',
                  actionLabel: 'Gerenciar horários',
                  onAction: () => context.push('/manage-availability'),
                )
              : EmptyState(
                  icon: Icons.calendar_month_rounded,
                  title: 'Nenhuma reserva ainda',
                  message: 'Descubra anfitriões e marque seu primeiro encontro.',
                  actionLabel: 'Explorar anfitriões',
                  onAction: () => context.go('/'),
                );
        }
        final upcoming = bookings.where((b) => b.isUpcoming).toList()
          ..sort((a, b) => a.startAt!.compareTo(b.startAt!));
        final past = bookings.where((b) => !b.isUpcoming).toList();

        return RefreshIndicator(
          onRefresh: () => ref.refresh(provider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x20,
              AppSpacing.x16,
              AppSpacing.x20,
              AppSpacing.x24,
            ),
            children: [
              if (upcoming.isNotEmpty) ...[
                const _Header('Próximos'),
                for (final b in upcoming) _BookingCard(booking: b, asHost: asHost),
              ],
              if (past.isNotEmpty) ...[
                const _Header('Anteriores'),
                for (final b in past) _BookingCard(booking: b, asHost: asHost),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x8, top: AppSpacing.x8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _BookingCard extends ConsumerStatefulWidget {
  const _BookingCard({required this.booking, required this.asHost});

  final BookingModel booking;
  final bool asHost;

  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> {
  bool _busy = false;

  BookingModel get booking => widget.booking;

  void _refreshLists() {
    ref.invalidate(myBookingsProvider);
    ref.invalidate(receivedBookingsProvider);
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  Future<void> _cancel() async {
    final paid = booking.paymentStatus == 'captured';
    final String detail;
    if (widget.asHost) {
      detail = paid
          ? 'O cliente recebe o valor de volta e o horário sai da sua agenda.'
          : 'O horário sai da sua agenda.';
    } else if (!paid) {
      detail = 'Nada foi cobrado por esta reserva.';
    } else if (booking.refundableIfCancelled) {
      detail = 'Você recebe ${booking.amountLabel} de volta no cartão.';
    } else {
      detail = 'Faltam menos de ${AppConstants.freeCancellationHours}h para o '
          'encontro, então o valor não será reembolsado.';
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar reserva?'),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(bookingRepositoryProvider).cancelBooking(booking.id);
      _refreshLists();
      _snack('Reserva cancelada.');
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      final outcome = await ref.read(paymentFlowProvider).pay(booking);
      if (outcome == PaymentOutcome.paid) _snack('Pagamento aprovado. Reserva confirmada!');
      _refreshLists();
    } catch (e) {
      _snack(e.toString(), error: true);
      _refreshLists();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review() async {
    final sent = await showReviewSheet(context, booking);
    if (sent) {
      _refreshLists();
      _snack('Obrigado pela avaliação!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final counterpartName = widget.asHost
        ? (booking.client?.name ?? 'Cliente')
        : (booking.host?.name ?? 'Anfitrião');
    final counterpartAvatar =
        widget.asHost ? booking.client?.avatarUrl : booking.host?.avatarUrl;
    final counterpartUserId =
        widget.asHost ? booking.client?.id : booking.hostUserId;

    final actions = <Widget>[
      if (counterpartUserId != null && booking.status != BookingStatus.cancelled)
        TextButton.icon(
          onPressed: _busy
              ? null
              : () => openChatWith(context, ref, counterpartUserId),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          label: const Text('Mensagem'),
        ),
      if (!widget.asHost && booking.awaitingPayment && booking.isUpcoming)
        TextButton.icon(
          onPressed: _busy ? null : _pay,
          icon: const Icon(Icons.lock_rounded, size: 18),
          label: const Text('Pagar'),
        ),
      if (!widget.asHost && booking.canReview)
        TextButton.icon(
          onPressed: _busy ? null : _review,
          icon: const Icon(Icons.star_outline_rounded, size: 18),
          label: const Text('Avaliar'),
        ),
      if (booking.canCancel)
        TextButton(
          onPressed: _busy ? null : _cancel,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Cancelar'),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(url: counterpartAvatar, name: counterpartName, radius: 26),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(counterpartName, style: t.titleMedium),
                      const SizedBox(height: AppSpacing.x2),
                      Text(booking.amountLabel, style: t.bodyMedium),
                    ],
                  ),
                ),
                _StatusPill(booking: booking),
              ],
            ),
            const SizedBox(height: AppSpacing.x12),
            Row(
              children: [
                const Icon(Icons.event_rounded, size: 16, color: AppColors.ink400),
                const SizedBox(width: AppSpacing.x8),
                Expanded(
                  child: Text(
                    booking.dateTimeLabel,
                    style: t.bodyMedium?.copyWith(color: AppColors.ink700),
                  ),
                ),
                if (booking.review != null)
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 16, color: AppColors.rating),
                      Text(' ${booking.review!.rating}', style: t.labelLarge),
                    ],
                  ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x8),
              const Divider(height: 1),
              Wrap(alignment: WrapAlignment.end, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.booking});

  final BookingModel booking;

  ({String label, Color fg, Color bg}) get _style => switch (booking.status) {
        BookingStatus.pending => (
            label: 'Aguardando pagamento',
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
            label: booking.cancelledByHost
                ? 'Cancelada pelo anfitrião'
                : 'Cancelada',
            fg: AppColors.error,
            bg: AppColors.errorBg,
          ),
        BookingStatus.disputed => (
            label: 'Em análise',
            fg: AppColors.error,
            bg: AppColors.errorBg,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x10,
        vertical: AppSpacing.x6,
      ),
      decoration: BoxDecoration(color: s.bg, borderRadius: AppRadius.brPill),
      child: Text(
        s.label,
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: s.fg, letterSpacing: 0.2),
      ),
    );
  }
}
