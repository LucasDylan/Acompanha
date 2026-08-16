import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/host_profile_model.dart';
import '../../../../core/models/slot_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../providers/booking_provider.dart';

/// Horizontal row of selectable time cards (weekday / day / time) — reads like
/// a booking calendar rather than a wall of identical chips.
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
                    'Nenhum horário disponível agora. Volte em breve.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }

        return SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: available.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x12),
            itemBuilder: (context, i) => _SlotCard(
              slot: available[i],
              onTap: () => onSlotSelected(available[i]),
            ),
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
            itemBuilder: (_, __) => const SkeletonBox(width: 84, height: 104, radius: 16),
          ),
        ),
      ),
      error: (e, _) => Text(
        'Não foi possível carregar a disponibilidade.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.slot, required this.onTap});

  final SlotModel slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final weekday = DateFormat('EEE').format(slot.startAt);
    final day = DateFormat('d').format(slot.startAt);
    final time = DateFormat('HH:mm').format(slot.startAt);

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brLg,
        child: Container(
          width: 84,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brLg,
            border: Border.all(color: AppColors.ink200, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekday.toUpperCase(),
                style: t.labelSmall?.copyWith(color: AppColors.ink400),
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(day, style: t.headlineSmall),
              const SizedBox(height: AppSpacing.x6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x8,
                  vertical: AppSpacing.x2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: AppRadius.brPill,
                ),
                child: Text(
                  time,
                  style: t.labelSmall?.copyWith(color: AppColors.brand600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
