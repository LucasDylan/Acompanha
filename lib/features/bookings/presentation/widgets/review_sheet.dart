import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/booking_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../booking/providers/booking_provider.dart';

/// Asks the client to rate a meeting that happened. Returns true when sent.
Future<bool> showReviewSheet(BuildContext context, BookingModel booking) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReviewSheet(booking: booking),
  );
  return sent ?? false;
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.booking});

  final BookingModel booking;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  int _rating = 0;
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final text = _comment.text.trim();
      await ref.read(bookingRepositoryProvider).reviewBooking(
            widget.booking.id,
            rating: _rating,
            comment: text.isEmpty ? null : text,
          );
      if (mounted) Navigator.pop(context, true);
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
    final name = widget.booking.host?.name ?? 'o anfitrião';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x24,
        AppSpacing.x24,
        AppSpacing.x24,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.x24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Como foi com $name?', style: t.titleLarge),
          const SizedBox(height: AppSpacing.x16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 40,
                  tooltip: '$i',
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.rating,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x12),
          TextField(
            controller: _comment,
            maxLines: 3,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Conte como foi (opcional)',
            ),
          ),
          const SizedBox(height: AppSpacing.x12),
          AppButton(
            label: 'Enviar avaliação',
            isLoading: _sending,
            onPressed: _rating == 0 ? null : _send,
          ),
        ],
      ),
    );
  }
}
