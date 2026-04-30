import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException({
    this.message,
    this.statusCode,
    this.errors,
  });

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    String? message = data is Map ? data['detail']?.toString() : null;
    message ??= data is Map ? (data['message']?.toString()) : null;
    message ??= e.message ?? 'Network error';

    Map<String, List<String>>? errors;
    if (data is Map && data['errors'] != null) {
      errors = (data['errors'] as Map).map(
        (k, v) => MapEntry(
          k.toString(),
          (v is List ? v : [v]).map((e) => e.toString()).toList(),
        ),
      );
    }

    return ApiException(
      message: message,
      statusCode: e.response?.statusCode,
      errors: errors,
    );
  }

  final String? message;
  final int? statusCode;
  final Map<String, List<String>>? errors;

  @override
  String toString() => message ?? 'ApiException';
}
