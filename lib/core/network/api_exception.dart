import 'package:dio/dio.dart';

/// An API failure with a message that can be shown to the user as-is.
class ApiException implements Exception {
  ApiException({
    this.message,
    this.statusCode,
    this.errors,
  });

  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'O servidor demorou para responder. Tente novamente.',
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message: 'Sem conexão com o servidor. Verifique sua internet.',
        );
      default:
        break;
    }

    final status = e.response?.statusCode;
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
    message ??= errors?['non_field_errors']?.join(' ');
    message ??= (errors != null && errors.isNotEmpty)
        ? errors.values.first.join(' ')
        : null;
    if (message == null && status != null && status >= 500) {
      message = 'Erro no servidor. Tente novamente em instantes.';
    }
    message ??= 'Algo deu errado. Tente novamente.';

    return ApiException(message: message, statusCode: status, errors: errors);
  }

  final String? message;
  final int? statusCode;
  final Map<String, List<String>>? errors;

  /// First error the API reported for [field], if any.
  String? fieldError(String field) => errors?[field]?.join(' ');

  @override
  String toString() => message ?? 'Algo deu errado. Tente novamente.';
}

/// Runs [request] and turns Dio failures into [ApiException]s.
Future<T> guardApi<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
}
