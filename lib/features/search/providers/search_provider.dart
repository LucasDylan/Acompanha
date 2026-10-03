import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/geo/city_coordinates.dart';
import '../../../core/geo/geo_point.dart';
import '../../../core/models/host_profile_model.dart';
import '../../../core/services/location_service.dart';
import '../../discovery/data/discovery_repository.dart';
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

/// Hosts matching the typed query and city, searched on the server (so it
/// covers every host, not just the ones already loaded in Discover).
final searchAllHostsProvider =
    FutureProvider.autoDispose<List<HostProfileModel>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  final city = ref.watch(searchCityProvider);

  // Let typing settle before hitting the API; a newer keystroke rebuilds this
  // provider and the stale request is simply dropped.
  var superseded = false;
  ref.onDispose(() => superseded = true);
  await Future<void>.delayed(const Duration(milliseconds: 350));
  if (superseded) return const [];

  final page = await ref.read(discoveryRepositoryProvider).getHosts(
        filters: DiscoveryFilters(search: query, location: city),
        pageSize: 50,
      );
  return page.items;
});

/// Final, computed search results: distance annotation, radius filtering and
/// proximity sorting on top of the server's text/city matches.
final searchResultsProvider =
    Provider.autoDispose<AsyncValue<List<HostSearchResult>>>((ref) {
  final hostsAsync = ref.watch(searchAllHostsProvider);
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
