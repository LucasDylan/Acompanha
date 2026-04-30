import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/models/host_profile_model.dart';
import '../data/discovery_repository.dart';

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return DiscoveryRepository(apiClient: ref.watch(apiClientProvider));
});

final discoveryFiltersProvider =
    StateProvider<DiscoveryFilters?>((ref) => null);

final discoveryHostsProvider =
    FutureProvider.autoDispose<List<HostProfileModel>>((ref) async {
  final filters = ref.watch(discoveryFiltersProvider);
  return ref.read(discoveryRepositoryProvider).getHosts(filters: filters);
});
