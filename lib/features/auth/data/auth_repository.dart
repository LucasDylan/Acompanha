
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'saved_account.dart';

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
  static const _savedAccountsKey = 'saved_accounts';
  static const _maxSavedAccounts = 5;

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
    // Also drop the in-memory token so stale credentials don't leak into
    // later requests after a failed refresh.
    _client.setAccessToken(null);
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
      final user = UserModel.fromJson(userData);
      await _rememberAccount(user, refresh);
      return user;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<UserModel> loginWithFacebook(String accessToken) async {
    try {
      final res = await _client.dio.post(
        ApiConstants.facebookLogin,
        data: {'access_token': accessToken},
      );
      final data = res.data as Map<String, dynamic>;
      final access = data['access'] as String?;
      final refresh = data['refresh'] as String?;
      if (access == null) throw ApiException(message: 'No access token');

      await _saveTokens(access, refresh);
      _client.setAccessToken(access);
      _client.addAuthInterceptor();

      final userData = data['user'] as Map<String, dynamic>? ?? data;
      final user = UserModel.fromJson(userData);
      await _rememberAccount(user, refresh);
      return user;
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
      final userData = data['user'] as Map<String, dynamic>? ?? data;
      final user = UserModel.fromJson(userData);

      if (access != null) {
        await _saveTokens(access, refresh);
        _client.setAccessToken(access);
        _client.addAuthInterceptor();
        await _rememberAccount(user, refresh);
      }

      return user;
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

  Future<void> requestPasswordReset(String email) async {
    try {
      await _client.dio.post(
        ApiConstants.passwordResetRequest,
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _client.dio.post(
        ApiConstants.passwordResetConfirm,
        data: {'email': email, 'code': code, 'new_password': newPassword},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> logout() async {
    // JWT logout is client-side (clear tokens). Optional: call backend blacklist.
    await clearTokens();
    _client.setAccessToken(null);
  }

  Future<List<SavedAccount>> getSavedAccounts() async {
    final raw = await _storage.read(key: _savedAccountsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => SavedAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeSavedAccounts(List<SavedAccount> accounts) {
    return _storage.write(
      key: _savedAccountsKey,
      value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }

  /// Remembers this account on the device (by refresh token, never a
  /// password) so the login screen can offer a one-tap "quick login" next
  /// time, without the user retyping their password.
  Future<void> _rememberAccount(UserModel user, String? refreshToken) async {
    if (refreshToken == null) return;
    final accounts = await getSavedAccounts();
    accounts.removeWhere((a) => a.email == user.email);
    accounts.insert(
      0,
      SavedAccount(
        email: user.email,
        refreshToken: refreshToken,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
      ),
    );
    await _writeSavedAccounts(accounts.take(_maxSavedAccounts).toList());
  }

  /// Removes a saved account from this device AND asks the server to
  /// permanently blacklist its refresh token — so it can't be replayed even
  /// if it had already been copied off the device before removal.
  Future<void> removeSavedAccount(String email) async {
    final accounts = await getSavedAccounts();
    final matches = accounts.where((a) => a.email == email);
    final removed = matches.isEmpty ? null : matches.first;
    accounts.removeWhere((a) => a.email == email);
    await _writeSavedAccounts(accounts);

    if (removed != null) {
      try {
        await _client.dio.post(
          ApiConstants.revokeToken,
          data: {'refresh': removed.refreshToken},
        );
      } catch (_) {
        // Best-effort: the account is already gone from this device either
        // way, which is what the user asked for. Server-side revocation is
        // a bonus that may not land if offline — not worth blocking on.
      }
    }
  }

  /// Logs in using a saved account's refresh token instead of a password.
  /// If the refresh token has expired server-side, the account is dropped
  /// from the saved list so it stops being offered.
  Future<UserModel> loginWithSavedAccount(SavedAccount account) async {
    try {
      final res = await _client.dio.post(
        ApiConstants.refresh,
        data: {'refresh': account.refreshToken},
      );
      final access = (res.data as Map)['access']?.toString();
      if (access == null) throw ApiException(message: 'Sessão expirada');

      await _saveTokens(access, account.refreshToken);
      _client.setAccessToken(access);
      _client.addAuthInterceptor();

      final user = await getCurrentUser();
      if (user == null) throw ApiException(message: 'Sessão expirada');
      return user;
    } on DioException catch (e) {
      await removeSavedAccount(account.email);
      throw ApiException.fromDio(e);
    }
  }
}
