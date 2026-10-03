import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/fitness.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../models/match_request_model.dart';
import '../../providers/matches_provider.dart';

/// Invites a partner to a workout at a given time. Returns true when sent.
Future<bool> showScheduleSessionSheet(
  BuildContext context,
  MatchPartner partner,
) async {
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ScheduleSessionSheet(partner: partner),
  );
  return created ?? false;
}

class _ScheduleSessionSheet extends ConsumerStatefulWidget {
  const _ScheduleSessionSheet({required this.partner});

  final MatchPartner partner;

  @override
  ConsumerState<_ScheduleSessionSheet> createState() =>
      _ScheduleSessionSheetState();
}

class _ScheduleSessionSheetState extends ConsumerState<_ScheduleSessionSheet> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  int _duration = 60;
  String? _workout;
  final _notes = TextEditingController();
  bool _saving = false;

  static const _durations = [45, 60, 90, 120];

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  DateTime get _start =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _save() async {
    if (!_start.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha um horário no futuro.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final notes = _notes.text.trim();
      await ref.read(matchesRepositoryProvider).createSession(
            partnerId: widget.partner.id,
            scheduledAt: _start,
            durationMinutes: _duration,
            workoutType: _workout,
            notes: notes.isEmpty ? null : notes,
          );
      ref.invalidate(sessionsProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x24,
        AppSpacing.x24,
        AppSpacing.x24,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.x24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Treinar com ${widget.partner.label}', style: t.titleLarge),
            const SizedBox(height: AppSpacing.x20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(formatDayMonth(_date)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule_outlined, size: 18),
                    label: Text(_time.format(context)),
                    onPressed: () async {
                      final picked =
                          await showTimePicker(context: context, initialTime: _time);
                      if (picked != null) setState(() => _time = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x16),
            Text('Duração', style: t.labelLarge),
            const SizedBox(height: AppSpacing.x8),
            Wrap(
              spacing: AppSpacing.x8,
              children: [
                for (final m in _durations)
                  ChoiceChip(
                    label: Text(formatDuration(m)),
                    selected: _duration == m,
                    onSelected: (_) => setState(() => _duration = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x16),
            Text('Treino', style: t.labelLarge),
            const SizedBox(height: AppSpacing.x8),
            Wrap(
              spacing: AppSpacing.x8,
              runSpacing: AppSpacing.x8,
              children: [
                for (final w in Fitness.workoutTypes)
                  ChoiceChip(
                    label: Text(w),
                    selected: _workout == w,
                    onSelected: (sel) => setState(() => _workout = sel ? w : null),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x16),
            TextField(
              controller: _notes,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Observações (opcional) — ex.: "treino de perna"',
              ),
            ),
            const SizedBox(height: AppSpacing.x20),
            AppButton(
              label: 'Enviar convite',
              icon: Icons.send_rounded,
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
