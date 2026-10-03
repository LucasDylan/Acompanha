import 'dart:async';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';

/// Where the client reads and renews the session tokens. Implemented by the
/// auth layer on top of secure storage.
abstract class TokenStore {
  Future<String?> readRefreshToken();
  Future<void> saveAccessToken(String token);
}

/// Shared Dio client. Attaches the access token to every request and, when the
/// API answers 401 because that token expired (it lives 1h), trades the
/// refresh token for a new one and retries the request once — so a session
/// survives for the refresh token's 7 days instead of dying after an hour.
class ApiClient {
  ApiClient({String? baseUrl, Dio? dio, Dio? refreshDio})
      : dio = dio ?? Dio(),
        _refreshDio = refreshDio ?? Dio() {
    final options = BaseOptions(
      baseUrl: baseUrl ?? ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    );
    this.dio.options = options;
    _refreshDio.options = options.copyWith();
    this.dio.interceptors.add(_AuthInterceptor(this));
  }

  final Dio dio;
  final Dio _refreshDio;
  String? _accessToken;
  Future<String?>? _refreshing;

  TokenStore? tokenStore;

  /// Called when the session can't be renewed (refresh token expired or
  /// revoked) so the app can send the user back to the login screen.
  void Function()? onSessionExpired;

  String? get accessToken => _accessToken;

  void setAccessToken(String? token) => _accessToken = token;

  /// Renews the access token. Concurrent callers share one network round-trip.
  Future<String?> refreshAccessToken() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _refresh() async {
    final refresh = await tokenStore?.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return null;
    try {
      final res = await _refreshDio.post(
        ApiConstants.refresh,
        data: {'refresh': refresh},
      );
      final access = (res.data as Map)['access']?.toString();
      if (access == null) return null;
      _accessToken = access;
      await tokenStore?.saveAccessToken(access);
      return access;
    } on DioException {
      return null;
    }
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._client);

  final ApiClient _client;

  static const _retriedKey = 'auth_retried';

  /// Endpoints that must never receive an Authorization header. Django's JWT
  /// authentication validates any Bearer token *before* the view's `AllowAny`
  /// permission, so sending a stale/expired token here returns 401
  /// ("token inválido") and blocks login/register/refresh entirely.
  static const _publicPaths = [
    '/auth/login',
    '/auth/register',
    '/auth/facebook',
    '/auth/password-reset',
    '/auth/token/refresh',
    '/auth/revoke',
  ];

  bool _isPublic(RequestOptions options) =>
      _publicPaths.any((p) => options.path.contains(p));

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _client.accessToken;
    if (!_isPublic(options) && token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final canRetry = err.response?.statusCode == 401 &&
        !_isPublic(options) &&
        options.extra[_retriedKey] != true &&
        _client.accessToken != null;
    if (!canRetry) return handler.next(err);

    final newToken = await _client.refreshAccessToken();
    if (newToken == null) {
      _client.onSessionExpired?.call();
      return handler.next(err);
    }

    try {
      final data = options.data;
      final retry = options.copyWith(
        data: data is FormData ? data.clone() : data,
        extra: {...options.extra, _retriedKey: true},
        headers: {...options.headers, 'Authorization': 'Bearer $newToken'},
      );
      handler.resolve(await _client.dio.fetch(retry));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
