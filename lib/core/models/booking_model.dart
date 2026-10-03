import '../utils/formatters.dart';
import 'host_profile_model.dart';
import 'slot_model.dart';

enum BookingStatus {
  pending, // awaiting payment
  confirmed, // paid, meeting scheduled
  completed,
  cancelled,
  disputed,
}

/// The person who booked, as the host sees them.
class BookingClient {
  const BookingClient({required this.id, this.displayName, this.avatarUrl});

  factory BookingClient.fromJson(Map<String, dynamic> json) => BookingClient(
        id: json['id'].toString(),
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );

  final String id;
  final String? displayName;
  final String? avatarUrl;

  String get name =>
      (displayName?.trim().isNotEmpty ?? false) ? displayName! : 'Cliente';
}

class BookingReview {
  const BookingReview({required this.rating, this.comment});

  factory BookingReview.fromJson(Map<String, dynamic> json) => BookingReview(
        rating: json['rating'] as int,
        comment: json['comment'] as String?,
      );

  final int rating;
  final String? comment;
}

class BookingModel {
  const BookingModel({
    required this.id,
    required this.clientId,
    required this.hostId,
    required this.slotId,
    required this.status,
    required this.amount,
    this.hostUserId,
    this.currency = 'BRL',
    this.slot,
    this.host,
    this.client,
    this.startAt,
    this.endAt,
    this.createdAt,
    this.paymentStatus,
    this.cancelledByHost = false,
    this.refundableIfCancelled = false,
    this.review,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) => json[key] != null
        ? DateTime.parse(json[key] as String).toLocal()
        : null;
    return BookingModel(
      id: json['id'].toString(),
      clientId: json['client_id'].toString(),
      hostId: json['host_id'].toString(),
      hostUserId: json['host_user_id']?.toString(),
      slotId: json['slot_id'].toString(),
      status: _statusFromString(json['status'] as String?),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'BRL',
      slot: json['slot'] != null
          ? SlotModel.fromJson(json['slot'] as Map<String, dynamic>)
          : null,
      host: json['host'] != null
          ? HostProfileModel.fromJson(json['host'] as Map<String, dynamic>)
          : null,
      client: json['client'] != null
          ? BookingClient.fromJson(json['client'] as Map<String, dynamic>)
          : null,
      startAt: date('start_at'),
      endAt: date('end_at'),
      createdAt: date('created_at'),
      paymentStatus: json['payment_status'] as String?,
      cancelledByHost: json['cancelled_by_host'] as bool? ?? false,
      refundableIfCancelled: json['refundable_if_cancelled'] as bool? ?? false,
      review: json['review'] != null
          ? BookingReview.fromJson(json['review'] as Map<String, dynamic>)
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
  final String? hostUserId;
  final String slotId;
  final BookingStatus status;
  final double amount;
  final String currency;
  final SlotModel? slot;
  final HostProfileModel? host;
  final BookingClient? client;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? createdAt;
  final String? paymentStatus;
  final bool cancelledByHost;
  final bool refundableIfCancelled;
  final BookingReview? review;

  bool get isUpcoming =>
      startAt != null && startAt!.isAfter(DateTime.now());

  bool get canCancel =>
      isUpcoming &&
      (status == BookingStatus.pending || status == BookingStatus.confirmed);

  bool get canReview => status == BookingStatus.completed && review == null;

  bool get awaitingPayment => status == BookingStatus.pending;

  String get amountLabel => formatMoney(amount, currency);

  String get dateTimeLabel {
    if (startAt == null) return '';
    return '${formatDayMonth(startAt!)} · ${formatTime(startAt!)}';
  }
}
