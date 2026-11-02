import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../data/safety_repository.dart';
import '../providers/safety_provider.dart';

/// Asks, then blocks [name]. Returns true when they were blocked.
Future<bool> blockPerson(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Bloquear $name?'),
      content: const Text(
        'Vocês não vão mais se ver no app nem conversar, e a parceria de treino, '
        'se houver, acaba. Reservas já feitas continuam em Reservas. Dá para '
        'desbloquear em Perfil › Privacidade e segurança.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Bloquear'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(safetyRepositoryProvider).block(userId);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
    );
    return false;
  }
  refreshPeopleLists(ref);
  messenger.showSnackBar(SnackBar(content: Text('Você bloqueou $name.')));
  return true;
}

/// Lets the user report [name] (and block them at the same time). Returns
/// true when they were also blocked.
Future<bool> reportPerson(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
  String? conversationId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final blocked = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(
      userId: userId,
      name: name,
      conversationId: conversationId,
    ),
  );
  if (blocked == null) return false; // closed without sending
  if (blocked) refreshPeopleLists(ref);
  messenger.showSnackBar(
    const SnackBar(
      content: Text('Denúncia enviada. Obrigado por avisar; vamos analisar.'),
    ),
  );
  return blocked;
}

enum _SafetyAction { report, block }

/// "⋮" menu with Denunciar / Bloquear, for app bars. [onBlocked] runs once the
/// person is blocked (usually to leave their screen).
class SafetyMenuButton extends ConsumerWidget {
  const SafetyMenuButton({
    super.key,
    required this.userId,
    required this.name,
    this.conversationId,
    this.onBlocked,
  });

  final String userId;
  final String name;
  final String? conversationId;
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_SafetyAction>(
      tooltip: 'Mais opções',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) async {
        final bool blocked;
        if (action == _SafetyAction.report) {
          blocked = await reportPerson(
            context,
            ref,
            userId: userId,
            name: name,
            conversationId: conversationId,
          );
        } else {
          blocked = await blockPerson(context, ref, userId: userId, name: name);
        }
        if (blocked) onBlocked?.call();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _SafetyAction.report,
          child: ListTile(
            leading: Icon(Icons.flag_outlined),
            title: Text('Denunciar'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _SafetyAction.block,
          child: ListTile(
            leading: Icon(Icons.block_rounded),
            title: Text('Bloquear'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.userId,
    required this.name,
    this.conversationId,
  });

  final String userId;
  final String name;
  final String? conversationId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportReason? _reason;
  bool _alsoBlock = true;
  bool _sending = false;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref.read(safetyRepositoryProvider).report(
            userId: widget.userId,
            reason: _reason!,
            details: _details.text,
            conversationId: widget.conversationId,
            block: _alsoBlock,
          );
      if (mounted) Navigator.pop(context, _alsoBlock);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
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
            Text('Denunciar ${widget.name}', style: t.titleLarge),
            const SizedBox(height: AppSpacing.x4),
            Text(
              'A denúncia é anônima: a pessoa não fica sabendo quem denunciou.',
              style: t.bodyMedium?.copyWith(color: AppColors.ink600),
            ),
            const SizedBox(height: AppSpacing.x12),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (r) => setState(() => _reason = r),
              child: Column(
                children: [
                  for (final reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      value: reason,
                      title: Text(reason.label),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Conte o que aconteceu (opcional)',
              ),
            ),
            SwitchListTile(
              value: _alsoBlock,
              onChanged: (v) => setState(() => _alsoBlock = v),
              title: Text('Também bloquear ${widget.name}'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.x12),
            AppButton(
              label: 'Enviar denúncia',
              isLoading: _sending,
              onPressed: _reason == null ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
