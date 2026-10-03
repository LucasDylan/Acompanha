import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/slot_model.dart';
import '../data/booking_repository.dart';
import '../data/payment_flow.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(apiClient: ref.watch(apiClientProvider));
});

final paymentFlowProvider = Provider<PaymentFlow>((ref) {
  return PaymentFlow(ref.watch(bookingRepositoryProvider));
});

final hostSlotsProvider =
    FutureProvider.autoDispose.family<List<SlotModel>, String>((ref, hostId) {
  return ref.read(bookingRepositoryProvider).getHostSlots(hostId);
});

final hostReviewsProvider =
    FutureProvider.autoDispose.family<List<HostReview>, String>((ref, hostId) {
  return ref.read(bookingRepositoryProvider).getHostReviews(hostId);
});

/// Bookings the user made.
final myBookingsProvider =
    FutureProvider.autoDispose<List<BookingModel>>((ref) {
  return ref.read(bookingRepositoryProvider).getMyBookings();
});

/// Bookings other people made with the user's host listing.
final receivedBookingsProvider =
    FutureProvider.autoDispose<List<BookingModel>>((ref) {
  return ref.read(bookingRepositoryProvider).getMyBookings(asHost: true);
});
