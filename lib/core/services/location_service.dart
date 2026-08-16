import 'package:geolocator/geolocator.dart';

import '../geo/geo_point.dart';

enum LocationStatus { success, serviceDisabled, denied, deniedForever, error }

/// Outcome of a location request — carries the point on success and a reason
/// otherwise, so the UI can show a precise message instead of a silent null.
class LocationResult {
  const LocationResult(this.status, [this.point]);

  final LocationStatus status;
  final GeoPoint? point;

  bool get isSuccess => status == LocationStatus.success && point != null;

  String? get message => switch (status) {
        LocationStatus.success => null,
        LocationStatus.serviceDisabled =>
          'Ative a localização do aparelho para buscar por perto.',
        LocationStatus.denied => 'Permissão de localização negada.',
        LocationStatus.deniedForever =>
          'Permissão bloqueada. Habilite nas configurações do app.',
        LocationStatus.error => 'Não foi possível obter sua localização.',
      };
}

/// Thin wrapper over `geolocator`, handling the service-enabled check and the
/// permission flow in one call.
class LocationService {
  const LocationService();

  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationStatus.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(LocationStatus.denied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      return LocationResult(
        LocationStatus.success,
        GeoPoint(position.latitude, position.longitude),
      );
    } catch (_) {
      return const LocationResult(LocationStatus.error);
    }
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}
