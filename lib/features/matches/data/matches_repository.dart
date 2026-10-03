import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/models/host_profile_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/match_request_model.dart';

/// The free "train together" flow: browse people at your gym and exchange
/// mutual match requests. Unlike [DiscoveryRepository] this never falls back to
/// mock data — an empty feed here is a real signal (no gym set, or no one else
/// at that gym yet), and hiding it behind fake profiles would be misleading.
class MatchesRepository {
  MatchesRepository({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    final raw = data is Map ? (data['results'] ?? const []) : data;
    if (raw is! List) return [];
    return raw.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Other members of the caller's gym. Empty when the user has no gym set.
  Future<List<HostProfileModel>> getGymMembers({
    String? fitnessLevel,
    String? workoutType,
    String? search,
  }) async {
    try {
      final res = await _client.dio.get(
        ApiConstants.gymMembers,
        queryParameters: {
          if (fitnessLevel != null) 'fitness_level': fitnessLevel,
          if (workoutType != null) 'workout_type': workoutType,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      return _list(res.data, HostProfileModel.fromGymMember);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Sends a request to train together. The backend auto-accepts when the other
  /// person had already sent one to us, so the result can come back `accepted`.
  Future<MatchRequestModel> sendRequest(String receiverId) async {
    try {
      final res = await _client.dio.post(
        ApiConstants.matchRequest,
        data: {'receiver_id': int.tryParse(receiverId) ?? receiverId},
      );
      return MatchRequestModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<MatchRequestModel>> getIncoming() async {
    try {
      final res = await _client.dio.get(ApiConstants.matchesIncoming);
      return _list(res.data, MatchRequestModel.fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<MatchRequestModel>> getMyMatches() async {
    try {
      final res = await _client.dio.get(ApiConstants.matches);
      return _list(res.data, MatchRequestModel.fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<MatchRequestModel> respond({
    required String requestId,
    required bool accept,
  }) async {
    try {
      final res = await _client.dio.post(
        ApiConstants.matchRespond(requestId),
        data: {'action': accept ? 'accept' : 'decline'},
      );
      return MatchRequestModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
