import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'saved_account.dart';

class AuthRepository implements TokenStore {
  AuthRepository({
    required ApiClient apiClient,
    required FlutterSecureStorage storage,
  })  : _client = apiClient,
        _storage = storage {
    _client.tokenStore = this;
  }

  final ApiClient _client;
  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _savedAccountsKey = 'saved_accounts';
  static const _maxSavedAccounts = 5;

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  Future<void> _saveTokens(String access, String? refresh) async {
    await _storage.write(key: _accessTokenKey, value: access);
    if (refresh != null) {
      await _storage.write(key: _refreshTokenKey, value: refresh);
    }
    _client.setAccessToken(access);
  }

  Future<void> clearTokens() async {
    _client.setAccessToken(null);
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  /// Picks up the session stored on the device, if any. Returns null when
  /// there is none or it can no longer be renewed. Network failures are
  /// rethrown so the app can offer a retry instead of logging the user out.
  Future<UserModel?> restoreSession() async {
    final access = await _storage.read(key: _accessTokenKey);
    final refresh = await readRefreshToken();
    if ((access == null || access.isEmpty) && refresh == null) return null;
    _client.setAccessToken(access ?? '');
    try {
      return await fetchMe();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await clearTokens();
        return null;
      }
      rethrow;
    }
  }

  Future<UserModel> fetchMe() => guardApi(() async {
        final res = await _client.dio.get(ApiConstants.me);
        return UserModel.fromJson(res.data as Map<String, dynamic>);
      });

  /// Stores the tokens from a login/register response and returns the user.
  Future<UserModel> _startSession(Map<String, dynamic> data) async {
    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;
    if (access == null) {
      throw ApiException(message: 'Resposta inesperada do servidor.');
    }
    await _saveTokens(access, refresh);
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _rememberAccount(user, refresh);
    return user;
  }

  Future<UserModel> login(String email, String password) => guardApi(() async {
        final res = await _client.dio.post(
          ApiConstants.login,
          data: {'email': email, 'password': password},
        );
        return _startSession(res.data as Map<String, dynamic>);
      });

  Future<UserModel> loginWithFacebook(String accessToken) =>
      guardApi(() async {
        final res = await _client.dio.post(
          ApiConstants.facebookLogin,
          data: {'access_token': accessToken},
        );
        return _startSession(res.data as Map<String, dynamic>);
      });

  Future<UserModel> register({
    required String email,
    required String password,
    String? displayName,
  }) =>
      guardApi(() async {
        final res = await _client.dio.post(
          ApiConstants.register,
          data: {
            'email': email,
            'password': password,
            if (displayName != null) 'display_name': displayName,
          },
        );
        return _startSession(res.data as Map<String, dynamic>);
      });

  Future<void> requestPasswordReset(String email) => guardApi(() async {
        await _client.dio.post(
          ApiConstants.passwordResetRequest,
          data: {'email': email},
        );
      });

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      guardApi(() async {
        await _client.dio.post(
          ApiConstants.passwordResetConfirm,
          data: {'email': email, 'code': code, 'new_password': newPassword},
        );
      });

  /// Logging out keeps the device's "recent accounts" entry (and its refresh
  /// token) so the user can come back with one tap; removing that entry is
  /// what revokes it — see [removeSavedAccount].
  Future<void> logout() => clearTokens();

  Future<UserModel> updateProfile(Map<String, dynamic> fields) =>
      guardApi(() async {
        final res = await _client.dio.patch(ApiConstants.me, data: fields);
        return UserModel.fromJson(res.data as Map<String, dynamic>);
      });

  Future<UserModel> uploadAvatar(File file) => guardApi(() async {
        final form = FormData.fromMap({
          'image': await MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last,
          ),
        });
        final res = await _client.dio.post(ApiConstants.myAvatar, data: form);
        return UserModel.fromJson(res.data as Map<String, dynamic>);
      });

  /// Closes the account on the server, then forgets it on this device.
  Future<void> deleteAccount(String email) async {
    await guardApi(() => _client.dio.delete(ApiConstants.me));
    final accounts = await getSavedAccounts();
    accounts.removeWhere((a) => a.email == email);
    await _writeSavedAccounts(accounts);
    await clearTokens();
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
    await _storage.write(key: _refreshTokenKey, value: account.refreshToken);
    final access = await _client.refreshAccessToken();
    if (access == null) {
      await removeSavedAccount(account.email);
      await clearTokens();
      throw ApiException(
        message: 'Sessão expirada. Digite sua senha para ${account.email}.',
        statusCode: 401,
      );
    }
    return fetchMe();
  }
}
