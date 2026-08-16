import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/models/host_profile_model.dart';
import '../data/discovery_repository.dart';

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return DiscoveryRepository(apiClient: ref.watch(apiClientProvider));
});

final discoveryFiltersProvider =
    StateProvider<DiscoveryFilters?>((ref) => null);

/// Currently selected category quick-filter (null = "All"). Applied
/// client-side so the chip row stays responsive and works with mock data.
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final discoveryHostsProvider =
    FutureProvider.autoDispose<List<HostProfileModel>>((ref) async {
  final filters = ref.watch(discoveryFiltersProvider);
  return ref.read(discoveryRepositoryProvider).getHosts(filters: filters);
});

/// Hosts after applying the [selectedCategoryProvider] quick-filter.
final filteredHostsProvider =
    Provider.autoDispose<AsyncValue<List<HostProfileModel>>>((ref) {
  final hostsAsync = ref.watch(discoveryHostsProvider);
  final category = ref.watch(selectedCategoryProvider);
  return hostsAsync.whenData((hosts) {
    if (category == null) return hosts;
    return hosts.where((h) => h.categories.contains(category)).toList();
  });
});
