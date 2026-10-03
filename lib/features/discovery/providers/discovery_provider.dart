import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/models/host_profile_model.dart';
import '../data/discovery_repository.dart';

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return DiscoveryRepository(apiClient: ref.watch(apiClientProvider));
});

/// Filters for the Discover feed (chips and the filter sheet both write here).
final discoveryFiltersProvider =
    StateProvider.autoDispose<DiscoveryFilters>((ref) => const DiscoveryFilters());

class HostFeed {
  const HostFeed({
    required this.items,
    required this.page,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<HostProfileModel> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  HostFeed copyWith({
    List<HostProfileModel>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) =>
      HostFeed(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

/// The Discover feed, a page at a time. Changing the filters starts over.
final discoveryFeedProvider =
    AsyncNotifierProvider.autoDispose<DiscoveryFeedNotifier, HostFeed>(
  DiscoveryFeedNotifier.new,
);

class DiscoveryFeedNotifier extends AutoDisposeAsyncNotifier<HostFeed> {
  DiscoveryFilters get _filters => ref.read(discoveryFiltersProvider);

  @override
  Future<HostFeed> build() async {
    final filters = ref.watch(discoveryFiltersProvider);
    final page =
        await ref.read(discoveryRepositoryProvider).getHosts(filters: filters);
    return HostFeed(items: page.items, page: 1, hasMore: page.hasMore);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final next = await ref
          .read(discoveryRepositoryProvider)
          .getHosts(filters: _filters, page: current.page + 1);
      state = AsyncData(current.copyWith(
        items: [...current.items, ...next.items],
        page: current.page + 1,
        hasMore: next.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }
}
