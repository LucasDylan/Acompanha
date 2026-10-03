import '../../../core/constants/api_constants.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/slot_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// What the server says about taking payments right now.
class PaymentConfig {
  const PaymentConfig({
    required this.enabled,
    this.publishableKey,
    this.unpaidBookingsAllowed = false,
  });

  factory PaymentConfig.fromJson(Map<String, dynamic> json) => PaymentConfig(
        enabled: json['enabled'] as bool? ?? false,
        publishableKey: json['publishable_key'] as String?,
        unpaidBookingsAllowed: json['unpaid_bookings_allowed'] as bool? ?? false,
      );

  final bool enabled;
  final String? publishableKey;

  /// Development mode: bookings are confirmed without charging.
  final bool unpaidBookingsAllowed;
}

class HostReview {
  const HostReview({
    required this.rating,
    required this.author,
    required this.createdAt,
    this.comment,
  });

  factory HostReview.fromJson(Map<String, dynamic> json) => HostReview(
        rating: json['rating'] as int,
        author: json['author'] as String? ?? 'Cliente',
        comment: (json['comment'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['comment'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );

  final int rating;
  final String author;
  final String? comment;
  final DateTime createdAt;
}

class BookingRepository {
  BookingRepository({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  List<dynamic> _results(dynamic data) =>
      data is List ? data : (data['results'] as List? ?? const []);

  /// The host's open, upcoming slots.
  Future<List<SlotModel>> getHostSlots(String hostId) => guardApi(() async {
        final res = await _client.dio.get(ApiConstants.hostSlots(hostId));
        return _results(res.data)
            .map((e) => SlotModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<BookingModel> createBooking({
    required String slotId,
    required String hostId,
  }) =>
      guardApi(() async {
        final res = await _client.dio.post(
          ApiConstants.bookings,
          data: {
            'slot_id': int.tryParse(slotId) ?? slotId,
            'host_id': int.tryParse(hostId) ?? hostId,
          },
        );
        return BookingModel.fromJson(res.data as Map<String, dynamic>);
      });

  /// Bookings the user made, or with [asHost] the ones they received.
  Future<List<BookingModel>> getMyBookings({bool asHost = false}) =>
      guardApi(() async {
        final res = await _client.dio.get(
          ApiConstants.bookings,
          queryParameters: {'page_size': 50, if (asHost) 'role': 'host'},
        );
        return _results(res.data)
            .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<BookingModel> cancelBooking(String bookingId) => guardApi(() async {
        final res =
            await _client.dio.post(ApiConstants.cancelBooking(bookingId));
        return BookingModel.fromJson(res.data as Map<String, dynamic>);
      });

  Future<void> reviewBooking(
    String bookingId, {
    required int rating,
    String? comment,
  }) =>
      guardApi(() async {
        await _client.dio.post(
          ApiConstants.reviewBooking(bookingId),
          data: {'rating': rating, if (comment != null) 'comment': comment},
        );
      });

  Future<List<HostReview>> getHostReviews(String hostId) => guardApi(() async {
        final res = await _client.dio.get(ApiConstants.profileReviews(hostId));
        return _results(res.data)
            .map((e) => HostReview.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<PaymentConfig> getPaymentConfig() => guardApi(() async {
        final res = await _client.dio.get(ApiConstants.paymentConfig);
        return PaymentConfig.fromJson(res.data as Map<String, dynamic>);
      });

  Future<String> createPaymentIntent(String bookingId) => guardApi(() async {
        final res = await _client.dio.post(
          ApiConstants.createPaymentIntent,
          data: {'booking_id': int.tryParse(bookingId) ?? bookingId},
        );
        return (res.data as Map)['client_secret'] as String;
      });

  /// Tells the server the payment sheet succeeded. Returns the payment status.
  Future<String> capturePayment(String bookingId) => guardApi(() async {
        final res =
            await _client.dio.post(ApiConstants.capturePayment(bookingId));
        return (res.data as Map)['status'] as String? ?? '';
      });
}
