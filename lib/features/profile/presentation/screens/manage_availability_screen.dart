import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/slot_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../providers/profile_provider.dart';

class ManageAvailabilityScreen extends ConsumerWidget {
  const ManageAvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myProfile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meus horários')),
      body: myProfile.when(
        loading: () => const AppLoading(),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Não foi possível carregar seu perfil',
          message: e.toString(),
          tone: EmptyStateTone.error,
          actionLabel: 'Tentar de novo',
          onAction: () => ref.invalidate(myProfileProvider),
        ),
        data: (profile) {
          if (profile == null) {
            return EmptyState(
              icon: Icons.workspace_premium_rounded,
              title: 'Crie seu perfil de anfitrião primeiro',
              message: 'Você precisa ter um perfil de anfitrião para publicar horários.',
              actionLabel: 'Criar perfil',
              onAction: () => context.push('/host-profile/edit'),
            );
          }
          return _SlotsList(hostId: profile.id);
        },
      ),
      floatingActionButton: myProfile.maybeWhen(
        data: (profile) => profile == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showAddSlotSheet(context, ref, profile.id),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar horário'),
              ),
        orElse: () => null,
      ),
    );
  }

  void _showAddSlotSheet(BuildContext context, WidgetRef ref, String hostId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddSlotSheet(hostId: hostId),
    );
  }
}

class _SlotsList extends ConsumerWidget {
  const _SlotsList({required this.hostId});

  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(mySlotsProvider(hostId));

    return slotsAsync.when(
      loading: () => const AppLoading(),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Erro ao carregar horários',
        message: e.toString(),
        tone: EmptyStateTone.error,
        actionLabel: 'Tentar de novo',
        onAction: () => ref.invalidate(mySlotsProvider(hostId)),
      ),
      data: (slots) {
        if (slots.isEmpty) {
          return const EmptyState(
            icon: Icons.calendar_month_outlined,
            title: 'Nenhum horário publicado',
            message: 'Toque em "Adicionar horário" para os clientes poderem te encontrar e reservar.',
          );
        }
        final sorted = [...slots]..sort((a, b) => a.startAt.compareTo(b.startAt));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x20, AppSpacing.x16, AppSpacing.x20, AppSpacing.x32,
          ),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x12),
          itemBuilder: (context, i) => _SlotTile(hostId: hostId, slot: sorted[i]),
        );
      },
    );
  }
}

class _SlotTile extends ConsumerWidget {
  const _SlotTile({required this.hostId, required this.slot});

  final String hostId;
  final SlotModel slot;

  Color _statusColor() => switch (slot.status) {
        SlotStatus.available => AppColors.success,
        SlotStatus.booked => AppColors.brand,
        SlotStatus.cancelled => AppColors.ink400,
        SlotStatus.past => AppColors.ink400,
      };

  String _statusLabel() => switch (slot.status) {
        SlotStatus.available => 'Disponível',
        SlotStatus.booked => 'Reservado',
        SlotStatus.cancelled => 'Cancelado',
        SlotStatus.past => 'Encerrado',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(toBeginningOfSentenceCase(slot.dateLabel), style: t.titleSmall),
                const SizedBox(height: AppSpacing.x4),
                Text(slot.timeLabel, style: t.bodyMedium?.copyWith(color: AppColors.ink500)),
                const SizedBox(height: AppSpacing.x8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8, vertical: AppSpacing.x2),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.12),
                    borderRadius: AppRadius.brPill,
                  ),
                  child: Text(
                    _statusLabel(),
                    style: t.labelSmall?.copyWith(color: _statusColor(), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (slot.isAvailable)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Remover horário?'),
                    content: const Text('Esse horário deixará de ficar disponível para reserva.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
                    ],
                  ),
                );
                if (confirmed != true) return;
                try {
                  await ref.read(mySlotsProvider(hostId).notifier).deleteSlot(slot.id);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}

class _AddSlotSheet extends ConsumerStatefulWidget {
  const _AddSlotSheet({required this.hostId});

  final String hostId;

  @override
  ConsumerState<_AddSlotSheet> createState() => _AddSlotSheetState();
}

class _AddSlotSheetState extends ConsumerState<_AddSlotSheet> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _durationMinutes = 60;
  bool _saving = false;

  static const _durationOptions = [30, 60, 90, 120];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final start = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final end = start.add(Duration(minutes: _durationMinutes));
    if (!start.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha um horário no futuro.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(mySlotsProvider(widget.hostId).notifier)
          .createSlot(startAt: start, endAt: end);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dateFmt = DateFormat('EEEE, d MMM', 'pt_BR');
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.x24,
        right: AppSpacing.x24,
        top: AppSpacing.x24,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.x24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Novo horário', style: t.titleLarge),
          const SizedBox(height: AppSpacing.x20),
          _PickerRow(
            icon: Icons.calendar_today_outlined,
            label: dateFmt.format(_date),
            onTap: _pickDate,
          ),
          const SizedBox(height: AppSpacing.x12),
          _PickerRow(
            icon: Icons.schedule_outlined,
            label: _time.format(context),
            onTap: _pickTime,
          ),
          const SizedBox(height: AppSpacing.x12),
          Text('Duração', style: t.labelLarge),
          const SizedBox(height: AppSpacing.x8),
          Wrap(
            spacing: AppSpacing.x8,
            children: _durationOptions.map((m) {
              final selected = m == _durationMinutes;
              return ChoiceChip(
                label: Text(m < 60 ? '$m min' : '${m ~/ 60}h${m % 60 == 0 ? '' : ' ${m % 60}min'}'),
                selected: selected,
                onSelected: (_) => setState(() => _durationMinutes = m),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.x24),
          AppButton(
            label: 'Publicar horário',
            glow: true,
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink100,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        borderRadius: AppRadius.brMd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16, vertical: AppSpacing.x16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.ink700),
              const SizedBox(width: AppSpacing.x12),
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: AppColors.ink400),
            ],
          ),
        ),
      ),
    );
  }
}
