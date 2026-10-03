/// App-wide limits shared with the API's validation.
class AppConstants {
  AppConstants._();

  static const String appName = 'Acompanha';
  static const String supportEmail = 'suporte@acompanha.app';

  static const int maxPhotosPerProfile = 6;
  static const int maxBioLength = 500;
  static const int minPasswordLength = 8;
  static const int minSlotDurationMinutes = 30;
  static const int maxSlotDurationMinutes = 480; // 8 hours

  /// Matches the server's FREE_CANCELLATION_HOURS default.
  static const int freeCancellationHours = 24;
}
