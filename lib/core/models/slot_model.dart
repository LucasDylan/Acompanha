import 'package:intl/intl.dart';

enum SlotStatus { available, booked, past, cancelled }

class SlotModel {
  const SlotModel({
    required this.id,
    required this.hostId,
    required this.startAt,
    required this.endAt,
    this.status = SlotStatus.available,
    this.bookingId,
  });

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
      status: _statusFromString(json['status'] as String?),
      bookingId: json['booking_id'] as String?,
    );
  }

  static SlotStatus _statusFromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'booked':
        return SlotStatus.booked;
      case 'past':
        return SlotStatus.past;
      case 'cancelled':
        return SlotStatus.cancelled;
      default:
        return SlotStatus.available;
    }
  }

  final String id;
  final String hostId;
  final DateTime startAt;
  final DateTime endAt;
  final SlotStatus status;
  final String? bookingId;

  bool get isAvailable => status == SlotStatus.available;

  String get timeLabel {
    final f = DateFormat('HH:mm');
    return '${f.format(startAt)} - ${f.format(endAt)}';
  }

  String get dateLabel => DateFormat('MMM d, y').format(startAt);
}
