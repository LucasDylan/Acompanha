
import '../../../core/constants/api_constants.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/slot_model.dart';
import '../../../core/network/api_client.dart';

class BookingRepository {
  BookingRepository({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  Future<List<SlotModel>> getHostSlots(String hostId, {DateTime? from}) async {
    try {
      final res = await _client.dio.get(
        ApiConstants.hostSlots(hostId),
        queryParameters: from != null ? {'from': from.toIso8601String()} : null,
      );
      final data = res.data;
      List<dynamic> list = data is List ? data : (data['results'] ?? data['slots'] ?? []);
      return list.map((e) => SlotModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _mockSlots(hostId);
    }
  }

  Future<BookingModel> createBooking({
    required String slotId,
    required String hostId,
  }) async {
    final res = await _client.dio.post(
      ApiConstants.bookings,
      data: {'slot_id': slotId, 'host_id': hostId},
    );
    return BookingModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<String> createPaymentIntent(String bookingId) async {
    final res = await _client.dio.post(
      ApiConstants.createPaymentIntent,
      data: {'booking_id': bookingId},
    );
    return (res.data as Map)['client_secret'] as String? ?? '';
  }

  Future<BookingModel> confirmBooking(String bookingId) async {
    final res = await _client.dio.post(ApiConstants.confirmBooking(bookingId));
    return BookingModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<BookingModel>> getMyBookings() async {
    try {
      final res = await _client.dio.get(ApiConstants.bookings);
      final data = res.data;
      List<dynamic> list = data is List ? data : (data['results'] ?? []);
      return list.map((e) => BookingModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  List<SlotModel> _mockSlots(String hostId) {
    final now = DateTime.now();
    return List.generate(5, (i) {
      final start = now.add(Duration(days: i + 1, hours: 9 + (i % 4)));
      return SlotModel(
        id: 's$i',
        hostId: hostId,
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
        status: SlotStatus.available,
      );
    });
  }
}
