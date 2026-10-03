import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/gym_member_model.dart';
import '../models/match_request_model.dart';

/// The free "train together" flow: browse people at your gym, exchange mutual
/// match requests and schedule workouts together. Never falls back to mock
/// data — an empty feed here is a real signal (no gym set, or no one else at
/// that gym yet).
class MatchesRepository {
  MatchesRepository({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    final raw = data is Map ? (data['results'] ?? const []) : data;
    if (raw is! List) return [];
    return raw.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  int _id(String id) => int.tryParse(id) ?? 0;

  /// Other members of the caller's gym. Empty when the user has no gym set.
  Future<List<GymMemberModel>> getGymMembers({String? workoutType}) =>
      guardApi(() async {
        final res = await _client.dio.get(
          ApiConstants.gymMembers,
          queryParameters: {
            'page_size': 100,
            if (workoutType != null) 'workout_type': workoutType,
          },
        );
        return _list(res.data, GymMemberModel.fromJson);
      });

  /// Sends a request to train together. The backend auto-accepts when the other
  /// person had already sent one to us, so the result can come back `accepted`.
  Future<MatchRequestModel> sendRequest(String receiverId) => guardApi(() async {
        final res = await _client.dio.post(
          ApiConstants.matchRequest,
          data: {'receiver_id': _id(receiverId)},
        );
        return MatchRequestModel.fromJson(res.data as Map<String, dynamic>);
      });

  Future<List<MatchRequestModel>> getIncoming() => guardApi(() async {
        final res = await _client.dio.get(ApiConstants.matchesIncoming);
        return _list(res.data, MatchRequestModel.fromJson);
      });

  Future<List<MatchRequestModel>> getMyMatches() => guardApi(() async {
        final res = await _client.dio.get(ApiConstants.matches);
        return _list(res.data, MatchRequestModel.fromJson);
      });

  Future<MatchRequestModel> respond({
    required String requestId,
    required bool accept,
  }) =>
      guardApi(() async {
        final res = await _client.dio.post(
          ApiConstants.matchRespond(requestId),
          data: {'action': accept ? 'accept' : 'decline'},
        );
        return MatchRequestModel.fromJson(res.data as Map<String, dynamic>);
      });

  Future<List<TrainingSessionModel>> getSessions() => guardApi(() async {
        final res = await _client.dio.get(ApiConstants.sessions);
        return _list(res.data, TrainingSessionModel.fromJson);
      });

  Future<TrainingSessionModel> createSession({
    required String partnerId,
    required DateTime scheduledAt,
    required int durationMinutes,
    String? workoutType,
    String? notes,
  }) =>
      guardApi(() async {
        final res = await _client.dio.post(
          ApiConstants.sessions,
          data: {
            'partner_id': _id(partnerId),
            'scheduled_at': scheduledAt.toUtc().toIso8601String(),
            'duration_minutes': durationMinutes,
            if (workoutType != null) 'workout_type': workoutType,
            if (notes != null) 'notes': notes,
          },
        );
        return TrainingSessionModel.fromJson(res.data as Map<String, dynamic>);
      });

  Future<void> confirmSession(String id) =>
      guardApi(() => _client.dio.post(ApiConstants.confirmSession(id)));

  Future<void> cancelSession(String id) =>
      guardApi(() => _client.dio.post(ApiConstants.cancelSession(id)));
}
