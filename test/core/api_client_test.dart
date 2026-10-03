import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_apollo/core/network/api_client.dart';
import 'package:projeto_apollo/core/network/api_exception.dart';

import '../support/fake_api.dart';

class _MemoryTokens implements TokenStore {
  _MemoryTokens(this.refresh);

  String? refresh;
  String? savedAccess;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> saveAccessToken(String token) async => savedAccess = token;
}

void main() {
  test('renews an expired access token and retries the request', () async {
    final api = FakeApi({
      'GET /auth/me/': (req) => req.headers['Authorization'] == 'Bearer new'
          ? jsonResponse(userJson())
          : jsonResponse({'detail': 'Token expirado'}, 401),
      'POST /auth/token/refresh/': (req) => req.data['refresh'] == 'refresh-1'
          ? jsonResponse({'access': 'new'})
          : jsonResponse({'detail': 'inválido'}, 401),
    });
    final tokens = _MemoryTokens('refresh-1');
    final client = api.client()
      ..tokenStore = tokens
      ..setAccessToken('old');

    final res = await client.dio.get('/auth/me/');

    expect(res.statusCode, 200);
    expect(client.accessToken, 'new');
    expect(tokens.savedAccess, 'new');
    expect(api.count('GET /auth/me/'), 2);
  });

  test('reports an expired session when the refresh token is rejected', () async {
    final api = FakeApi({
      'GET /bookings/': (_) => jsonResponse({'detail': 'Token expirado'}, 401),
      'POST /auth/token/refresh/': (_) => jsonResponse({'detail': 'blacklisted'}, 401),
    });
    var expired = false;
    final client = api.client()
      ..tokenStore = _MemoryTokens('revoked')
      ..setAccessToken('old')
      ..onSessionExpired = () => expired = true;

    await expectLater(
      guardApi(() => client.dio.get('/bookings/')),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(expired, isTrue);
  });

  test('parallel 401s share a single refresh call', () async {
    final api = FakeApi({
      'GET /a/': (req) => req.headers['Authorization'] == 'Bearer new'
          ? jsonResponse({'ok': true})
          : jsonResponse({}, 401),
      'GET /b/': (req) => req.headers['Authorization'] == 'Bearer new'
          ? jsonResponse({'ok': true})
          : jsonResponse({}, 401),
      'POST /auth/token/refresh/': (_) => jsonResponse({'access': 'new'}),
    });
    final client = api.client()
      ..tokenStore = _MemoryTokens('refresh-1')
      ..setAccessToken('old');

    await Future.wait([client.dio.get('/a/'), client.dio.get('/b/')]);

    expect(api.count('POST /auth/token/refresh/'), 1);
  });

  test('never sends the bearer token to login', () async {
    final api = FakeApi({
      'POST /auth/login/': (req) => jsonResponse({
            'had_auth': req.headers.containsKey('Authorization'),
          }),
    });
    final client = api.client()..setAccessToken('stale');

    final res = await client.dio.post('/auth/login/', data: {});

    expect(res.data['had_auth'], isFalse);
  });

  test('turns connection failures into a readable message', () async {
    final api = FakeApi({
      'GET /x/': (_) => throw Exception('socket closed'),
    });
    final client = api.client();

    await expectLater(
      guardApi(() => client.dio.get('/x/')),
      throwsA(isA<ApiException>()),
    );
  });
}
