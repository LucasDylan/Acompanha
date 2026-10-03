import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/host_profile_model.dart';
import '../../../../core/models/slot_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../providers/booking_provider.dart';

/// The host's open times, grouped by day, each showing its own price.
class SlotPicker extends ConsumerWidget {
  const SlotPicker({
    super.key,
    required this.host,
    required this.onSlotSelected,
  });

  final HostProfileModel host;
  final void Function(SlotModel slot) onSlotSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(hostSlotsProvider(host.id));
    final t = Theme.of(context).textTheme;

    return slotsAsync.when(
      data: (slots) {
        final available = slots.where((s) => s.isAvailable).toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

        if (available.isEmpty) {
          return AppCard(
            border: true,
            shadow: false,
            child: Row(
              children: [
                const Icon(Icons.event_busy_rounded, color: AppColors.ink400),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: Text(
                    '${host.name} não tem horários livres agora. Volte em breve.',
                    style: t.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }

        final byDay = <DateTime, List<SlotModel>>{};
        for (final s in available) {
          final day = DateUtils.dateOnly(s.startAt);
          byDay.putIfAbsent(day, () => []).add(s);
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final entry in byDay.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x8),
                  child: Text(
                    toBeginningOfSentenceCase(formatLongDate(entry.key)),
                    style: t.titleSmall,
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.x8,
                  runSpacing: AppSpacing.x8,
                  children: [
                    for (final slot in entry.value)
                      _SlotChip(
                        slot: slot,
                        price: host.pricePerHour == null
                            ? null
                            : formatMoney(
                                slot.priceFor(host.pricePerHour!),
                                host.currency,
                                compact: true,
                              ),
                        onTap: () => onSlotSelected(slot),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x16),
              ],
            ],
          ),
        );
      },
      loading: () => SizedBox(
        height: 104,
        child: ShimmerPlaceholder(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x12),
            itemBuilder: (_, __) =>
                const SkeletonBox(width: 84, height: 72, radius: 16),
          ),
        ),
      ),
      error: (e, _) => Row(
        children: [
          Expanded(
            child: Text(
              'Não foi possível carregar os horários. $e',
              style: t.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(hostSlotsProvider(host.id)),
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.slot, required this.onTap, this.price});

  final SlotModel slot;
  final String? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x12,
            vertical: AppSpacing.x8,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.ink200, width: 1.5),
          ),
          child: Column(
            children: [
              Text(formatTime(slot.startAt), style: t.titleSmall),
              Text(
                [formatDuration(slot.durationMinutes), if (price != null) price!]
                    .join(' · '),
                style: t.labelSmall?.copyWith(color: AppColors.brand600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
