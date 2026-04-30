/// API base URL and endpoints.
/// Use flavors or env vars for dev/staging/prod.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1', // Android emulator -> localhost
  );

  // Auth
  static const String login = '/auth/login/';
  static const String register = '/auth/register/';
  static const String refresh = '/auth/token/refresh/';
  static const String logout = '/auth/logout/';
  static const String me = '/auth/me/';

  // Profiles
  static const String profiles = '/profiles/';
  static String profile(String id) => '/profiles/$id/';
  static String profilePhotos(String id) => '/profiles/$id/photos/';

  // Slots
  static const String slots = '/slots/';
  static String hostSlots(String hostId) => '/profiles/$hostId/slots/';

  // Bookings
  static const String bookings = '/bookings/';
  static String booking(String id) => '/bookings/$id/';
  static String confirmBooking(String id) => '/bookings/$id/confirm/';
  static String cancelBooking(String id) => '/bookings/$id/cancel/';

  // Payments
  static const String createPaymentIntent = '/payments/create-intent/';
  static String capturePayment(String bookingId) =>
      '/payments/bookings/$bookingId/capture/';

  // Chat
  static const String conversations = '/conversations/';
  static String conversationMessages(String id) =>
      '/conversations/$id/messages/';

  // Discovery
  static const String discoverHosts = '/profiles/hosts/';
}
