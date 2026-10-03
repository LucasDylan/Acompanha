import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_apollo/app/routes/app_router.dart';
import 'package:projeto_apollo/core/di/providers.dart';

import 'fake_api.dart';

/// The real router, repositories and screens, with a plain theme (the app
/// theme pulls fonts from the network) and the HTTP layer faked.
Widget testApp(FakeApi api) {
  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api.client())],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(
        routerConfig: ref.watch(goRouterProvider),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
}

/// Phone-sized surface (iPhone 15-ish) so layouts are checked at real width.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Starts the app already logged in as [userJson].
void signedIn(Map<String, Handler> routes, {Map<String, dynamic>? user}) {
  FlutterSecureStorage.setMockInitialValues({
    'access_token': 'access-1',
    'refresh_token': 'refresh-1',
  });
  routes['GET /auth/me/'] ??= (_) => jsonResponse(user ?? userJson());
  routes['GET /conversations/unread-count/'] ??= (_) => jsonResponse({'unread': 0});
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}
