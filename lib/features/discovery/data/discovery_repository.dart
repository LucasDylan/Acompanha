
import '../../../core/constants/api_constants.dart';
import '../../../core/models/host_profile_model.dart';
import '../../../core/network/api_client.dart';

class DiscoveryFilters {
  const DiscoveryFilters({
    this.categories,
    this.minPrice,
    this.maxPrice,
    this.location,
    this.search,
  });

  final List<String>? categories;
  final double? minPrice;
  final double? maxPrice;
  final String? location;
  final String? search;

  Map<String, dynamic> toQueryParams() {
    final m = <String, dynamic>{};
    if (categories != null && categories!.isNotEmpty) {
      m['categories'] = categories!.join(',');
    }
    if (minPrice != null) m['min_price'] = minPrice;
    if (maxPrice != null) m['max_price'] = maxPrice;
    if (location != null && location!.isNotEmpty) m['location'] = location;
    if (search != null && search!.isNotEmpty) m['search'] = search;
    return m;
  }
}

class DiscoveryRepository {
  DiscoveryRepository({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  Future<List<HostProfileModel>> getHosts({
    DiscoveryFilters? filters,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final params = filters?.toQueryParams() ?? {};
      params['page'] = page;
      params['page_size'] = pageSize;

      final res = await _client.dio.get(
        ApiConstants.discoverHosts,
        queryParameters: params,
      );
      final data = res.data;
      if (data is Map && data['results'] != null) {
        return (data['results'] as List)
            .map((e) => HostProfileModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data is List) {
        return data
            .map((e) => HostProfileModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return _mockHosts();
    }
  }

  /// Mock data when backend is not available
  List<HostProfileModel> _mockHosts() {
    return [
      HostProfileModel(
        id: 'm1',
        userId: 'u1',
        displayName: 'Alex',
        bio: 'Coffee & networking enthusiast. Love meeting new people.',
        avatarUrl: null,
        photos: [],
        categories: ['Coffee', 'Networking'],
        pricePerHour: 25,
        rating: 4.8,
        reviewCount: 42,
        location: 'São Paulo',
      ),
      HostProfileModel(
        id: 'm2',
        userId: 'u2',
        displayName: 'Jordan',
        bio: 'Career mentor. 10+ years in tech.',
        avatarUrl: null,
        photos: [],
        categories: ['Mentorship', 'Networking'],
        pricePerHour: 50,
        rating: 4.9,
        reviewCount: 18,
        location: 'Rio de Janeiro',
      ),
      HostProfileModel(
        id: 'm3',
        userId: 'u3',
        displayName: 'Sam',
        bio: 'Language practice – English & Spanish.',
        avatarUrl: null,
        photos: [],
        categories: ['Language Practice'],
        pricePerHour: 20,
        rating: 4.6,
        reviewCount: 31,
        location: 'Belo Horizonte',
      ),
      HostProfileModel(
        id: 'm4',
        userId: 'u4',
        displayName: 'Taylor',
        bio: 'Travel buddy for exploring new cities.',
        avatarUrl: null,
        photos: [],
        categories: ['Travel Companionship'],
        pricePerHour: 35,
        rating: 4.7,
        reviewCount: 12,
        location: 'Curitiba',
      ),
    ];
  }
}
