import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// API base URL and endpoints.
class ApiConstants {
  ApiConstants._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Dev default: each platform's loopback address for a Django server
  /// running on the host machine. Override with --dart-define=API_BASE_URL=
  /// for staging/prod or a physical device.
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:8000/api/v1';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000/api/v1'; // Android emulator -> host loopback
    return 'http://127.0.0.1:8000/api/v1'; // iOS simulator / desktop -> host loopback
  }

  // Auth
  static const String login = '/auth/login/';
  static const String facebookLogin = '/auth/facebook/';
  static const String passwordResetRequest = '/auth/password-reset/';
  static const String passwordResetConfirm = '/auth/password-reset/confirm/';
  static const String revokeToken = '/auth/revoke/';
  static const String register = '/auth/register/';
  static const String refresh = '/auth/token/refresh/';
  static const String me = '/auth/me/';
  static const String myAvatar = '/auth/me/avatar/';

  // Host profiles
  static const String myHostProfile = '/profiles/me/';
  static String profile(String id) => '/profiles/$id/';
  static String profilePhotos(String id) => '/profiles/$id/photos/';
  static String profileReviews(String id) => '/profiles/$id/reviews/';
  static String hostSlots(String hostId) => '/profiles/$hostId/slots/';
  static String hostSlot(String hostId, String slotId) =>
      '/profiles/$hostId/slots/$slotId/';

  // Discovery
  static const String discoverHosts = '/profiles/hosts/';

  // Bookings
  static const String bookings = '/bookings/';
  static String booking(String id) => '/bookings/$id/';
  static String cancelBooking(String id) => '/bookings/$id/cancel/';
  static String reviewBooking(String id) => '/bookings/$id/review/';

  // Payments
  static const String paymentConfig = '/payments/config/';
  static const String createPaymentIntent = '/payments/create-intent/';
  static String capturePayment(String bookingId) =>
      '/payments/bookings/$bookingId/capture/';

  // Chat
  static const String conversations = '/conversations/';
  static const String unreadCount = '/conversations/unread-count/';
  static String conversation(String id) => '/conversations/$id/';
  static String conversationMessages(String id) =>
      '/conversations/$id/messages/';

  // Gyms
  static const String gyms = '/gyms/';
  static const String gymMembers = '/gym-members/';

  // Matches (free "train together" flow between gym members)
  static const String matches = '/matches/';
  static const String matchRequest = '/matches/request/';
  static const String matchesIncoming = '/matches/incoming/';
  static String matchRespond(String id) => '/matches/$id/respond/';

  // Workouts scheduled between matched partners
  static const String sessions = '/sessions/';
  static String confirmSession(String id) => '/sessions/$id/confirm/';
  static String cancelSession(String id) => '/sessions/$id/cancel/';
}
