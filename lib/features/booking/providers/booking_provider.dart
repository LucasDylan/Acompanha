import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/slot_model.dart';
import '../data/booking_repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(apiClient: ref.watch(apiClientProvider));
});

final hostSlotsProvider =
    FutureProvider.autoDispose.family<List<SlotModel>, String>((ref, hostId) async {
  return ref.read(bookingRepositoryProvider).getHostSlots(hostId);
});

final myBookingsProvider =
    FutureProvider.autoDispose<List<BookingModel>>((ref) async {
  return ref.read(bookingRepositoryProvider).getMyBookings();
});
