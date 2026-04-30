import 'package:dio/dio.dart';

import '../constants/api_constants.dart';

/// Base Dio client with interceptors.
/// Use [ApiClient.addAuthInterceptor] when token is available.
class ApiClient {
  ApiClient({
    String? baseUrl,
    Dio? dio,
  })  : _baseUrl = baseUrl ?? ApiConstants.baseUrl,
        _dio = dio ?? Dio();

  final String _baseUrl;
  final Dio _dio;
  String? _accessToken;

  Dio get dio {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    return _dio;
  }

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  void addAuthInterceptor() {
    dio.interceptors.removeWhere((e) => e is AuthInterceptor);
    dio.interceptors.insert(0, AuthInterceptor(_accessToken));
  }

  void addLoggingInterceptor() {
    dio.interceptors.removeWhere((e) => e is LogInterceptor);
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._token);

  String? _token;

  set token(String? value) => _token = value;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_token != null && _token!.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $_token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expired - could trigger refresh here
    }
    handler.next(err);
  }
}
