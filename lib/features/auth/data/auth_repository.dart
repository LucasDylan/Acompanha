
import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required FlutterSecureStorage storage,
  })  : _client = apiClient,
        _storage = storage;

  final ApiClient _client;
  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> _saveTokens(String access, String? refresh) async {
    await _storage.write(key: _accessTokenKey, value: access);
    if (refresh != null) {
      await _storage.write(key: _refreshTokenKey, value: refresh);
    }
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<UserModel> login(String email, String password) async {
    try {
      final res = await _client.dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );
      final data = res.data as Map<String, dynamic>;
      final access = data['access'] as String?;
      final refresh = data['refresh'] as String?;
      if (access == null) throw ApiException(message: 'No access token');

      await _saveTokens(access, refresh);
      _client.setAccessToken(access);
      _client.addAuthInterceptor();

      final userData = data['user'] as Map<String, dynamic>? ?? data;
      return UserModel.fromJson(userData);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<UserModel> register({
    required String email,
    required String password,
    String? displayName,
    String role = 'client',
  }) async {
    try {
      final res = await _client.dio.post(
        ApiConstants.register,
        data: {
          'email': email,
          'password': password,
          if (displayName != null) 'display_name': displayName,
          'role': role,
        },
      );
      final data = res.data as Map<String, dynamic>;
      final access = data['access'] as String?;
      final refresh = data['refresh'] as String?;
      if (access != null) {
        await _saveTokens(access, refresh);
        _client.setAccessToken(access);
        _client.addAuthInterceptor();
      }

      final userData = data['user'] as Map<String, dynamic>? ?? data;
      return UserModel.fromJson(userData);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return null;

    _client.setAccessToken(token);
    _client.addAuthInterceptor();

    try {
      final res = await _client.dio.get(ApiConstants.me);
      return UserModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final refreshed = await _refreshToken();
        if (refreshed) return getCurrentUser();
        await clearTokens();
        return null;
      }
      rethrow;
    }
  }

  Future<bool> _refreshToken() async {
    final refresh = await getRefreshToken();
    if (refresh == null) return false;

    try {
      final res = await _client.dio.post(
        ApiConstants.refresh,
        data: {'refresh': refresh},
      );
      final access = (res.data as Map)['access']?.toString();
      if (access == null) return false;
      await _storage.write(key: _accessTokenKey, value: access);
      _client.setAccessToken(access);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    // JWT logout is client-side (clear tokens). Optional: call backend blacklist.
    await clearTokens();
    _client.setAccessToken(null);
  }
}
