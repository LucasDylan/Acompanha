import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/geo/city_coordinates.dart';
import '../../../core/geo/geo_point.dart';
import '../../../core/models/host_profile_model.dart';
import '../../../core/services/location_service.dart';
import '../../discovery/providers/discovery_provider.dart';

/// A host paired with its distance from the user (null when unknown).
class HostSearchResult {
  const HostSearchResult({required this.host, this.distanceKm});

  final HostProfileModel host;
  final double? distanceKm;

  String? get distanceLabel =>
      distanceKm == null ? null : formatDistanceKm(distanceKm!);
}

final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());

/// Free-text query (matches name, city or bio).
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Selected city quick-filter (null = any city).
final searchCityProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Whether the user opted in to "near me" (triggers GPS).
final useMyLocationProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Search radius in km (null = any distance). Only meaningful with location on.
final searchRadiusKmProvider =
    StateProvider.autoDispose<double?>((ref) => null);

/// Resolves the device location — only fetched when [useMyLocationProvider] is
/// on (it's watched conditionally in [searchResultsProvider]).
final userLocationProvider =
    FutureProvider.autoDispose<LocationResult>((ref) async {
  return ref.read(locationServiceProvider).current();
});

/// All hosts for search, independent of the Discover tab's filters.
final searchAllHostsProvider =
    FutureProvider.autoDispose<List<HostProfileModel>>((ref) async {
  return ref.read(discoveryRepositoryProvider).getHosts();
});

/// Final, computed search results: text + city + radius filtering, distance
/// annotation and proximity sorting — all client-side so it stays instant.
final searchResultsProvider =
    Provider.autoDispose<AsyncValue<List<HostSearchResult>>>((ref) {
  final hostsAsync = ref.watch(searchAllHostsProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final city = ref.watch(searchCityProvider);
  final useLocation = ref.watch(useMyLocationProvider);
  final radiusKm = ref.watch(searchRadiusKmProvider);

  // Only subscribe to GPS when the user opted in.
  final GeoPoint? userPoint = useLocation
      ? ref.watch(userLocationProvider).valueOrNull?.point
      : null;

  return hostsAsync.whenData((hosts) {
    var results = hosts.map((host) {
      double? distance;
      if (userPoint != null) {
        final coord = CityCoordinates.lookup(host.location);
        if (coord != null) distance = userPoint.distanceKm(coord);
      }
      return HostSearchResult(host: host, distanceKm: distance);
    }).toList();

    if (query.isNotEmpty) {
      results = results.where((r) {
        final name = (r.host.displayName ?? '').toLowerCase();
        final loc = (r.host.location ?? '').toLowerCase();
        final bio = (r.host.bio ?? '').toLowerCase();
        return name.contains(query) ||
            loc.contains(query) ||
            bio.contains(query);
      }).toList();
    }

    if (city != null) {
      final target = CityCoordinates.normalize(city);
      results = results.where((r) {
        final loc = r.host.location;
        return loc != null && CityCoordinates.normalize(loc).contains(target);
      }).toList();
    }

    if (userPoint != null && radiusKm != null) {
      results = results
          .where((r) => r.distanceKm != null && r.distanceKm! <= radiusKm)
          .toList();
    }

    // Sort by proximity whenever we have distances to sort by.
    if (userPoint != null) {
      results.sort((a, b) => (a.distanceKm ?? double.infinity)
          .compareTo(b.distanceKm ?? double.infinity));
    }

    return results;
  });
});
