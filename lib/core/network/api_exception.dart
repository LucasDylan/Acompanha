import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException({
    this.message,
    this.statusCode,
    this.errors,
  });

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;

    Map<String, List<String>>? errors;
    if (data is Map) {
      errors = data.map(
        (k, v) => MapEntry(
          k.toString(),
          (v is List ? v : [v]).map((e) => e.toString()).toList(),
        ),
      );
    }

    String? message = data is Map ? data['detail']?.toString() : null;
    message ??= data is Map ? data['message']?.toString() : null;
    message ??= errors?['non_field_errors']?.join(' ');
    message ??= (errors != null && errors.isNotEmpty)
        ? errors.values.first.join(' ')
        : null;
    message ??= e.message ?? 'Network error';

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
