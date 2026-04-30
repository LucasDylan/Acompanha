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

  Future<HostProfileModel> createHostProfile({
    required String displayName,
    String? bio,
    List<String>? categories,
    double? pricePerHour,
    String? location,
  }) async {
    final res = await _client.dio.post(
      ApiConstants.profiles,
      data: {
        'display_name': displayName,
        if (bio != null) 'bio': bio,
        if (categories != null) 'categories': categories,
        if (pricePerHour != null) 'price_per_hour': pricePerHour,
        if (location != null) 'location': location,
        'role': 'host',
      },
    );
    return HostProfileModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<HostProfileModel> updateProfile(
    String id, {
    String? displayName,
    String? bio,
    List<String>? categories,
    double? pricePerHour,
    String? location,
  }) async {
    final res = await _client.dio.patch(
      ApiConstants.profile(id),
      data: {
        if (displayName != null) 'display_name': displayName,
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
      'photo': await MultipartFile.fromFile(
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
    return data['url'] as String? ?? data['photo_url'] as String? ?? '';
  }

  Future<void> deletePhoto(String profileId, String photoUrl) async {
    await _client.dio.delete(
      ApiConstants.profilePhotos(profileId),
      data: {'url': photoUrl},
    );
  }
}
