import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:projeto_apollo/core/network/api_client.dart';

typedef Handler = ResponseBody Function(RequestOptions request);

ResponseBody jsonResponse(Object? body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Answers Dio requests from a table of `'METHOD /path/'` handlers, so tests
/// exercise the real repositories, interceptors and parsing end to end.
class FakeApi implements HttpClientAdapter {
  FakeApi([Map<String, Handler>? routes]) : routes = routes ?? {};

  final Map<String, Handler> routes;
  final List<RequestOptions> requests = [];

  int count(String route) =>
      requests.where((r) => '${r.method} ${r.path}' == route).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = routes['${options.method} ${options.path}'];
    if (handler == null) {
      return jsonResponse({'detail': 'Not found: ${options.path}'}, 404);
    }
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  ApiClient client() => ApiClient(
        baseUrl: 'http://test/api/v1',
        dio: Dio()..httpClientAdapter = this,
        refreshDio: Dio()..httpClientAdapter = this,
      );
}

Map<String, dynamic> userJson({
  int id = 1,
  String email = 'ana@test.com',
  String name = 'Ana',
  bool isHost = false,
}) =>
    {
      'id': id,
      'email': email,
      'display_name': name,
      'avatar_url': null,
      'gym': null,
      'fitness_level': 'beginner',
      'workout_types': <String>[],
      'available_days': <String>[],
      'bio': '',
      'age': null,
      'is_host': isHost,
      'host_profile_id': null,
    };

Map<String, dynamic> emptyPage() =>
    {'count': 0, 'next': null, 'previous': null, 'results': <Object>[]};
