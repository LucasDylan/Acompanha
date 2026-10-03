import '../../../core/constants/api_constants.dart';
import '../../../core/models/host_profile_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class DiscoveryFilters {
  const DiscoveryFilters({
    this.categories = const [],
    this.minPrice,
    this.maxPrice,
    this.location,
    this.search,
    this.trainersOnly = false,
  });

  /// Category slugs.
  final List<String> categories;
  final double? minPrice;
  final double? maxPrice;
  final String? location;
  final String? search;
  final bool trainersOnly;

  /// Number of filters set from the filter sheet (for the button badge).
  int get activeCount => [
        categories.isNotEmpty,
        minPrice != null,
        maxPrice != null,
        location?.isNotEmpty ?? false,
        trainersOnly,
      ].where((x) => x).length;

  DiscoveryFilters withCategories(List<String> value) => DiscoveryFilters(
        categories: value,
        minPrice: minPrice,
        maxPrice: maxPrice,
        location: location,
        search: search,
        trainersOnly: trainersOnly,
      );

  Map<String, dynamic> toQueryParams() => {
        if (categories.isNotEmpty) 'categories': categories.join(','),
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (location != null && location!.isNotEmpty) 'location': location,
        if (search != null && search!.isNotEmpty) 'search': search,
        if (trainersOnly) 'trainer': 1,
      };
}

class HostPage {
  const HostPage({required this.items, required this.hasMore});

  final List<HostProfileModel> items;
  final bool hasMore;
}

class DiscoveryRepository {
  DiscoveryRepository({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  Future<HostPage> getHosts({
    DiscoveryFilters filters = const DiscoveryFilters(),
    int page = 1,
    int pageSize = 20,
  }) =>
      guardApi(() async {
        final res = await _client.dio.get(
          ApiConstants.discoverHosts,
          queryParameters: {
            ...filters.toQueryParams(),
            'page': page,
            'page_size': pageSize,
          },
        );
        final data = res.data as Map<String, dynamic>;
        return HostPage(
          items: (data['results'] as List)
              .map((e) => HostProfileModel.fromJson(e as Map<String, dynamic>))
              .toList(),
          hasMore: data['next'] != null,
        );
      });
}
