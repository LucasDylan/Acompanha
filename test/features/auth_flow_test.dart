import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:projeto_apollo/features/auth/presentation/screens/login_screen.dart';
import 'package:projeto_apollo/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:projeto_apollo/features/profile/presentation/screens/register_screen.dart';

import '../support/fake_api.dart';
import '../support/test_app.dart';

Map<String, Handler> loggedInRoutes() => {
      'POST /auth/login/': (_) => jsonResponse({
            'user': userJson(),
            'access': 'access-1',
            'refresh': 'refresh-1',
          }),
      'GET /profiles/hosts/': (_) => jsonResponse(emptyPage()),
      'GET /conversations/unread-count/': (_) => jsonResponse({'unread': 0}),
    };

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('without a saved session the app opens on the login screen',
      (tester) async {
    await tester.pumpWidget(testApp(FakeApi()));
    await settle(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('a wrong password shows the reason and stays on login',
      (tester) async {
    final api = FakeApi({
      'POST /auth/login/': (_) =>
          jsonResponse({'detail': 'E-mail ou senha incorretos.'}, 401),
    });
    await tester.pumpWidget(testApp(api));
    await settle(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'ana@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'errada');
    await tester.tap(find.text('Entrar'));
    await settle(tester);

    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('logging in lands on Discover', (tester) async {
    final api = FakeApi(loggedInRoutes());
    await tester.pumpWidget(testApp(api));
    await settle(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'ana@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'Senha-Forte-123');
    await tester.tap(find.text('Entrar'));
    await settle(tester);

    expect(find.byType(DiscoveryScreen), findsOneWidget);
    expect(find.text('Nenhum anfitrião encontrado'), findsOneWidget);
  });

  testWidgets('a rejected sign-up keeps the form and shows the field error',
      (tester) async {
    final api = FakeApi({
      'POST /auth/register/': (_) => jsonResponse({
            'email': ['Já existe uma conta com este e-mail.'],
          }, 400),
    });
    await tester.pumpWidget(testApp(api));
    await settle(tester);

    await tester.ensureVisible(find.text('Criar uma conta'));
    await tester.tap(find.text('Criar uma conta'));
    await settle(tester);
    expect(find.byType(RegisterScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
    await tester.enterText(find.byType(TextFormField).at(1), 'ana@test.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'Senha-Forte-123');
    await tester.ensureVisible(find.text('Criar conta'));
    await tester.tap(find.text('Criar conta'));
    await settle(tester);

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Já existe uma conta com este e-mail.'), findsOneWidget);
  });

  testWidgets('a saved session is restored on startup', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'access-1',
      'refresh_token': 'refresh-1',
    });
    final api = FakeApi({
      ...loggedInRoutes(),
      'GET /auth/me/': (_) => jsonResponse(userJson()),
    });
    await tester.pumpWidget(testApp(api));
    await settle(tester);

    expect(find.byType(DiscoveryScreen), findsOneWidget);
  });

  testWidgets('a session that can no longer be renewed goes back to login',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'expired',
      'refresh_token': 'revoked',
    });
    final api = FakeApi({
      'GET /auth/me/': (_) => jsonResponse({'detail': 'expirado'}, 401),
      'POST /auth/token/refresh/': (_) => jsonResponse({'detail': 'revogado'}, 401),
    });
    await tester.pumpWidget(testApp(api));
    await settle(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
