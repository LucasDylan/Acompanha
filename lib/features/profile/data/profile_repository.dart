import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/models/gym_model.dart';
import '../../../core/models/host_profile_model.dart';
import '../../../core/models/slot_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class ProfileRepository {
  ProfileRepository({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  Future<HostProfileModel> getMyProfile() async {
    final res = await _client.dio.get('${ApiConstants.profiles}me/');
    return HostProfileModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<HostProfileModel> getProfile(String id) async {
    final res = await _client.dio.get(ApiConstants.profile(id));
    return HostProfileModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// Creates or updates the logged-in user's host profile.
  ///
  /// The backend route is `POST /profiles/me/` (MyHostProfileView), which
  /// performs an `update_or_create` — so this single call handles both the
  /// first-time creation and later edits. (Posting to `/profiles/` 404s: that
  /// path has no view.)
  Future<HostProfileModel> saveMyProfile({
    required String displayName,
    String? bio,
    List<String>? categories,
    double? pricePerHour,
    String? location,
  }) async {
    final res = await _client.dio.post(
      '${ApiConstants.profiles}me/',
      data: {
        'display_name': displayName,
        if (bio != null) 'bio': bio,
        if (categories != null) 'categories': categories,
        if (pricePerHour != null) 'price_per_hour': pricePerHour,
        if (location != null) 'location': location,
      },
    );
    return HostProfileModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<String> uploadPhoto(String profileId, File file) async {
    final formData = FormData.fromMap({
      // Backend (HostPhotoUploadView) expects the field name 'image'.
      'image': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });
    final res = await _client.dio.post(
      ApiConstants.profilePhotos(profileId),
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
      ),
    );
    final data = res.data as Map<String, dynamic>;
    return data['image'] as String? ??
        data['url'] as String? ??
        data['photo_url'] as String? ??
        '';
  }

  Future<void> deletePhoto(String profileId, String photoUrl) async {
    await _client.dio.delete(
      ApiConstants.profilePhotos(profileId),
      data: {'url': photoUrl},
    );
  }

  /// The host's own upcoming slots, for the availability-management screen.
  /// Unlike [BookingRepository.getHostSlots] this does not fall back to mock
  /// data on error — a host managing their own schedule needs to see real
  /// failures, not a demo placeholder.
  Future<List<SlotModel>> getMySlots(String hostId) async {
    try {
      final res = await _client.dio.get(ApiConstants.hostSlots(hostId));
      final data = res.data;
      final list = data is List ? data : (data['results'] ?? data['slots'] ?? []);
      return (list as List)
          .map((e) => SlotModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<SlotModel> createSlot({
    required String hostId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    try {
      final res = await _client.dio.post(
        ApiConstants.hostSlots(hostId),
        data: {
          'start_at': startAt.toIso8601String(),
          'end_at': endAt.toIso8601String(),
        },
      );
      return SlotModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> deleteSlot({required String hostId, required String slotId}) async {
    try {
      await _client.dio.delete(ApiConstants.hostSlot(hostId, slotId));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Gyms matching [query] (name or city). An empty query lists all of them.
  Future<List<GymModel>> searchGyms(String query) async {
    try {
      final res = await _client.dio.get(
        ApiConstants.gyms,
        queryParameters: {if (query.isNotEmpty) 'search': query},
      );
      final data = res.data;
      final raw = data is Map ? (data['results'] ?? const []) : data;
      if (raw is! List) return [];
      return raw
          .map((e) => GymModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<GymModel> createGym({required String name, String? city}) async {
    try {
      final res = await _client.dio.post(
        ApiConstants.gyms,
        data: {
          'name': name,
          if (city != null && city.isNotEmpty) 'city': city,
        },
      );
      return GymModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Sets which gym the logged-in user trains at — the prerequisite for the
  /// "train together" feed, which is scoped to gym mates.
  Future<void> setMyGym(String gymId) async {
    try {
      await _client.dio.patch(
        ApiConstants.me,
        data: {'gym_id': int.tryParse(gymId) ?? gymId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
