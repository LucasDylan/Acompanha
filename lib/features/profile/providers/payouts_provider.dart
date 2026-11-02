import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/payouts_repository.dart';

final payoutsRepositoryProvider = Provider<PayoutsRepository>((ref) {
  return PayoutsRepository(apiClient: ref.watch(apiClientProvider));
});

final payoutStatusProvider = FutureProvider.autoDispose<PayoutStatus>((ref) {
  return ref.read(payoutsRepositoryProvider).getStatus();
});
