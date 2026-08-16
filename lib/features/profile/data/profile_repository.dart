import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/models/host_profile_model.dart';
import '../../../core/network/api_client.dart';

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
}
