import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Whether the host can receive their share of bookings (Stripe Connect).
class PayoutStatus {
  const PayoutStatus({
    required this.needed,
    required this.connected,
    required this.ready,
    required this.feePercent,
  });

  factory PayoutStatus.fromJson(Map<String, dynamic> json) => PayoutStatus(
        needed: json['required'] == true,
        connected: json['connected'] == true,
        ready: json['ready'] == true,
        feePercent: (json['fee_percent'] as num?)?.toDouble() ?? 0,
      );

  /// Real payments are on, so hosts must set this up to be listed and booked.
  final bool needed;

  /// Started Stripe's sign-up at least once.
  final bool connected;
  final bool ready;

  /// Share of each booking the platform keeps.
  final double feePercent;

  String get feeLabel =>
      '${feePercent.toStringAsFixed(feePercent % 1 == 0 ? 0 : 1)}%';
}

class PayoutsRepository {
  PayoutsRepository({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  Future<PayoutStatus> getStatus() => guardApi(() async {
        final res = await _client.dio.get(ApiConstants.payouts);
        return PayoutStatus.fromJson(res.data as Map<String, dynamic>);
      });

  /// Stripe's sign-up page (identity and bank account), to open in a browser.
  Future<String> onboardingUrl() => guardApi(() async {
        final res = await _client.dio.post(ApiConstants.payoutsOnboarding);
        return (res.data as Map)['url'] as String;
      });

  /// The host's Stripe dashboard: balance, payouts and bank details.
  Future<String> dashboardUrl() => guardApi(() async {
        final res = await _client.dio.post(ApiConstants.payoutsDashboard);
        return (res.data as Map)['url'] as String;
      });
}
