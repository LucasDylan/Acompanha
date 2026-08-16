
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

  /// Mock data when backend is not available.
  ///
  /// Seeded with real portrait imagery (Unsplash) so the image-first UI can be
  /// demoed convincingly without a populated backend.
  List<HostProfileModel> _mockHosts() {
    String img(String id) =>
        'https://images.unsplash.com/photo-$id?auto=format&fit=crop&w=800&q=80';

    return [
      HostProfileModel(
        id: 'm1',
        userId: 'u1',
        displayName: 'Alex',
        bio:
            'Apaixonado por café e networking. Adoro conhecer gente nova e trocar ideias diante de um bom flat white.',
        avatarUrl: img('1494790108377-be9c29b29330'),
        photos: [
          img('1494790108377-be9c29b29330'),
          img('1517841905240-472988babdf9'),
          img('1524504388940-b1c1722653e1'),
        ],
        categories: ['Café', 'Networking'],
        pricePerHour: 120,
        currency: 'BRL',
        rating: 4.8,
        reviewCount: 42,
        location: 'São Paulo',
      ),
      HostProfileModel(
        id: 'm2',
        userId: 'u2',
        displayName: 'Jordan',
        bio:
            'Mentor de carreira com mais de 10 anos em tech. Ajudo você a se preparar para entrevistas, negociar propostas e ampliar sua rede.',
        avatarUrl: img('1507003211169-0a1dd7228f2d'),
        photos: [
          img('1507003211169-0a1dd7228f2d'),
          img('1506794778202-cad84cf45f1d'),
        ],
        categories: ['Mentoria', 'Networking'],
        pricePerHour: 240,
        currency: 'BRL',
        rating: 4.9,
        reviewCount: 18,
        location: 'Rio de Janeiro',
      ),
      HostProfileModel(
        id: 'm3',
        userId: 'u3',
        displayName: 'Sam',
        bio:
            'Inglês e espanhol em nível nativo. Prática de conversação descontraída sob medida para o seu objetivo — viagem, trabalho ou fluência.',
        avatarUrl: img('1438761681033-6461ffad8d80'),
        photos: [
          img('1438761681033-6461ffad8d80'),
          img('1534528741775-53994a69daeb'),
        ],
        categories: ['Prática de idiomas'],
        pricePerHour: 95,
        currency: 'BRL',
        rating: 4.6,
        reviewCount: 31,
        location: 'Belo Horizonte',
      ),
      HostProfileModel(
        id: 'm4',
        userId: 'u4',
        displayName: 'Taylor',
        bio:
            'Seu guia local para explorar os cantos escondidos da cidade. Cafés, mirantes e os lugares que os turistas não conhecem.',
        avatarUrl: img('1539571696357-5a69c17a67c6'),
        photos: [
          img('1539571696357-5a69c17a67c6'),
          img('1500648767791-00dcc994a43e'),
        ],
        categories: ['Acompanhamento de viagem'],
        pricePerHour: 160,
        currency: 'BRL',
        rating: 4.7,
        reviewCount: 12,
        location: 'Curitiba',
      ),
      HostProfileModel(
        id: 'm5',
        userId: 'u5',
        displayName: 'Maya',
        bio:
            'Designer e fundadora. Vamos tomar um café e falar sobre produto, portfólio e como entrar no design.',
        avatarUrl: img('1573496359142-b8d87734a5a2'),
        photos: [img('1573496359142-b8d87734a5a2')],
        categories: ['Mentoria', 'Café'],
        pricePerHour: 180,
        currency: 'BRL',
        rating: 5.0,
        reviewCount: 27,
        location: 'São Paulo',
      ),
      HostProfileModel(
        id: 'm6',
        userId: 'u6',
        displayName: 'Diego',
        bio:
            'Companhia tranquila para eventos, jantares e explorar a vida noturna. Boa conversa garantida.',
        avatarUrl: img('1500648767791-00dcc994a43e'),
        photos: [img('1500648767791-00dcc994a43e')],
        categories: ['Social casual', 'Acompanhamento de viagem'],
        pricePerHour: 140,
        currency: 'BRL',
        rating: 4.5,
        reviewCount: 9,
        location: 'Florianópolis',
      ),
    ];
  }
}
