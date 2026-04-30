import 'package:intl/intl.dart';

import 'host_profile_model.dart';
import 'slot_model.dart';

enum BookingStatus {
  pending,   // awaiting payment
  confirmed, // paid, meeting scheduled
  completed,
  cancelled,
  disputed,
}

class BookingModel {
  const BookingModel({
    required this.id,
    required this.clientId,
    required this.hostId,
    required this.slotId,
    required this.status,
    required this.amount,
    this.currency = 'USD',
    this.slot,
    this.host,
    this.startAt,
    this.endAt,
    this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      hostId: json['host_id'] as String,
      slotId: json['slot_id'] as String,
      status: _statusFromString(json['status'] as String?),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      slot: json['slot'] != null
          ? SlotModel.fromJson(json['slot'] as Map<String, dynamic>)
          : null,
      host: json['host'] != null
          ? HostProfileModel.fromJson(json['host'] as Map<String, dynamic>)
          : null,
      startAt: json['start_at'] != null
          ? DateTime.parse(json['start_at'] as String)
          : null,
      endAt:
          json['end_at'] != null ? DateTime.parse(json['end_at'] as String) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  static BookingStatus _statusFromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'disputed':
        return BookingStatus.disputed;
      default:
        return BookingStatus.pending;
    }
  }

  final String id;
  final String clientId;
  final String hostId;
  final String slotId;
  final BookingStatus status;
  final double amount;
  final String currency;
  final SlotModel? slot;
  final HostProfileModel? host;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? createdAt;

  bool get canChat => status == BookingStatus.confirmed ||
      status == BookingStatus.completed;

  String get amountLabel => '$currency ${amount.toStringAsFixed(2)}';

  String get dateTimeLabel {
    if (startAt == null) return '';
    return '${DateFormat('MMM d').format(startAt!)} at ${DateFormat('HH:mm').format(startAt!)}';
  }
}
