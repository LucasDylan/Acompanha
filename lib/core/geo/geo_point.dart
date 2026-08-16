import 'dart:math' as math;

/// A simple latitude/longitude pair plus distance math. Kept dependency-free so
/// it can be unit-tested without Flutter.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  /// Great-circle distance to [other] in kilometers (Haversine formula).
  double distanceKm(GeoPoint other) {
    const earthRadiusKm = 6371.0;
    final dLat = _rad(other.lat - lat);
    final dLng = _rad(other.lng - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat)) *
            math.cos(_rad(other.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _rad(double deg) => deg * (math.pi / 180.0);
}

/// Formats a distance for display: "<1 km", "12 km", "1.2k km".
String formatDistanceKm(double km) {
  if (km < 1) return '<1 km';
  if (km < 100) return '${km.round()} km';
  if (km < 1000) return '${km.round()} km';
  return '${(km / 1000).toStringAsFixed(1)}k km';
}
