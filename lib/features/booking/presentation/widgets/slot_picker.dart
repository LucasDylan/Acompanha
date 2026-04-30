import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/host_profile_model.dart';
import '../../../../core/models/slot_model.dart';
import '../../providers/booking_provider.dart';

class SlotPicker extends ConsumerWidget {
  const SlotPicker({
    super.key,
    required this.hostId,
    required this.host,
    required this.onSlotSelected,
  });

  final String hostId;
  final HostProfileModel host;
  final void Function(SlotModel slot) onSlotSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(hostSlotsProvider(hostId));

    return slotsAsync.when(
      data: (slots) {
        final available = slots.where((s) => s.isAvailable).toList();
        if (available.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No available slots. Check back later.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: available.map((slot) {
            return ActionChip(
              label: Text('${slot.dateLabel} • ${slot.timeLabel}'),
              onPressed: () => onSlotSelected(slot),
            );
          }).toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Text('Error loading slots: $e'),
    );
  }
}
