import 'geo_point.dart';

/// Static lookup of city → coordinates.
///
/// Hosts only store a city *name* (the backend has no lat/lng), so we map that
/// name to an approximate city-center coordinate. Combined with the device GPS
/// position this lets us compute a real "X km away" distance without any
/// backend change. Unknown cities simply return null (no distance shown).
class CityCoordinates {
  CityCoordinates._();

  /// Display name → coordinate. Keys are matched case/accent-insensitively.
  static const Map<String, GeoPoint> _cities = {
    'São Paulo': GeoPoint(-23.5505, -46.6333),
    'Rio de Janeiro': GeoPoint(-22.9068, -43.1729),
    'Belo Horizonte': GeoPoint(-19.9167, -43.9345),
    'Curitiba': GeoPoint(-25.4284, -49.2733),
    'Florianópolis': GeoPoint(-27.5949, -48.5482),
    'São José dos Campos': GeoPoint(-23.1896, -45.8841),
    'Brasília': GeoPoint(-15.7939, -47.8828),
    'Salvador': GeoPoint(-12.9777, -38.5016),
    'Porto Alegre': GeoPoint(-30.0346, -51.2177),
    'Recife': GeoPoint(-8.0476, -34.8770),
    'Fortaleza': GeoPoint(-3.7319, -38.5267),
    'Campinas': GeoPoint(-22.9099, -47.0626),
    'Goiânia': GeoPoint(-16.6869, -49.2648),
    'Manaus': GeoPoint(-3.1190, -60.0217),
    'Belém': GeoPoint(-1.4558, -48.5039),
    'Vitória': GeoPoint(-20.3155, -40.3128),
    'Natal': GeoPoint(-5.7945, -35.2110),
    'Santos': GeoPoint(-23.9608, -46.3336),
    'Niterói': GeoPoint(-22.8833, -43.1036),
  };

  /// Cities offered as quick chips (subset, ordered by relevance).
  static const List<String> popular = [
    'São Paulo',
    'Rio de Janeiro',
    'Belo Horizonte',
    'Curitiba',
    'Florianópolis',
    'São José dos Campos',
    'Brasília',
    'Porto Alegre',
  ];

  /// Lowercase + strip Portuguese diacritics for tolerant matching.
  static String normalize(String input) {
    var s = input.toLowerCase().trim();
    const map = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u',
      'ç': 'c',
    };
    map.forEach((k, v) => s = s.replaceAll(k, v));
    return s;
  }

  /// Resolve a host location string (e.g. "São Paulo", "Sao Paulo - SP") to a
  /// coordinate. Tries exact normalized match, then substring containment.
  static GeoPoint? lookup(String? location) {
    if (location == null || location.trim().isEmpty) return null;
    final norm = normalize(location);

    for (final entry in _cities.entries) {
      if (normalize(entry.key) == norm) return entry.value;
    }
    // Tolerate "City - UF" / "City, UF" by substring match.
    for (final entry in _cities.entries) {
      final key = normalize(entry.key);
      if (norm.contains(key) || key.contains(norm)) return entry.value;
    }
    return null;
  }
}
