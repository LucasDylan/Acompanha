import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/slot_model.dart';
import '../../../discovery/providers/discovery_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../providers/booking_provider.dart';
import '../widgets/payment_section.dart';

class BookingConfirmScreen extends ConsumerStatefulWidget {
  const BookingConfirmScreen({
    super.key,
    required this.hostId,
    this.slot,
  });

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

  Future<void> _confirmBooking() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    final slot = widget.slot;
    final hostId = widget.hostId;

    if (slot == null || hostId.isEmpty) {
      setState(() {
        _isProcessing = false;
        _error = 'Invalid booking data';
      });
      return;
    }

    final host = ref.read(hostProfileProvider(hostId)).valueOrNull ??
        ref.read(discoveryHostsProvider).valueOrNull?.where((h) => h.id == hostId).firstOrNull;

    if (host == null) {
      setState(() {
        _isProcessing = false;
        _error = 'Host not found';
      });
      return;
    }

    try {
      final repo = ref.read(bookingRepositoryProvider);
      final booking = await repo.createBooking(slotId: slot.id, hostId: hostId);
      ref.invalidate(myBookingsProvider);

      if (!mounted) return;
      context.go('/bookings');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking created: ${booking.amountLabel}')),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final hostId = widget.hostId;
    final host = ref.watch(hostProfileProvider(hostId)).valueOrNull ??
        ref.watch(discoveryHostsProvider).valueOrNull?.where((h) => h.id == hostId).firstOrNull;

    if (slot == null || host == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirm booking')),
        body: const Center(child: Text('Missing booking info')),
      );
    }

    final amount = host.pricePerHour ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm booking'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.displayName ?? 'Host',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('${slot.dateLabel} • ${slot.timeLabel}'),
                    const SizedBox(height: 16),
                    Text(
                      host.priceLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            PaymentSection(
              amount: amount,
              onPayPressed: _confirmBooking,
              isLoading: _isProcessing,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
