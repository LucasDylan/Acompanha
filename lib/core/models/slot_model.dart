import '../utils/formatters.dart';

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
      id: json['id'].toString(),
      hostId: json['host_id'].toString(),
      // The API sends UTC; show it in the phone's time zone.
      startAt: DateTime.parse(json['start_at'] as String).toLocal(),
      endAt: DateTime.parse(json['end_at'] as String).toLocal(),
      status: _statusFromString(json['status'] as String?),
      bookingId: json['booking_id']?.toString(),
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

  bool get isAvailable =>
      status == SlotStatus.available && startAt.isAfter(DateTime.now());

  int get durationMinutes => endAt.difference(startAt).inMinutes;

  String get timeLabel => '${formatTime(startAt)} – ${formatTime(endAt)}';

  String get dateLabel => formatDayMonth(startAt);

  /// What booking this slot costs at [pricePerHour].
  double priceFor(double pricePerHour) =>
      (pricePerHour * durationMinutes / 60 * 100).round() / 100;
}
