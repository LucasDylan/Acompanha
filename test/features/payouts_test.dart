import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../support/fake_api.dart';
import '../support/test_app.dart';

Map<String, dynamic> _myListing() => {
      'id': '30',
      'user_id': '1',
      'display_name': 'Ana',
      'bio': 'Café e conversa.',
      'avatar_url': null,
      'photos': <String>[],
      'categories': ['coffee'],
      'price_per_hour': 60.0,
      'currency': 'BRL',
      'rating': null,
      'review_count': 0,
      'location': 'São Paulo, SP',
      'is_trainer': false,
      'is_active': true,
    };

Future<void> openProfile(WidgetTester tester, Map<String, dynamic> payouts) async {
  usePhoneScreen(tester);
  final routes = <String, Handler>{
    'GET /profiles/hosts/': (_) => jsonResponse(emptyPage()),
    'GET /profiles/me/': (_) => jsonResponse(_myListing()),
    'GET /payments/payouts/': (_) => jsonResponse(payouts),
  };
  signedIn(routes, user: userJson(isHost: true));
  await tester.pumpWidget(testApp(FakeApi(routes)));
  await settle(tester);
  await tester.tap(find.text('Perfil'));
  await settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('a host who cannot be paid yet is asked to set up payouts',
      (tester) async {
    await openProfile(tester, {
      'required': true,
      'connected': false,
      'ready': false,
      'fee_percent': 15.0,
    });
    await tester.scrollUntilVisible(
      find.text('Configurar recebimentos'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Configure seus recebimentos'), findsOneWidget);
    expect(find.textContaining('15% de cada reserva'), findsOneWidget);
  });

  testWidgets('a host with payouts set up sees them as active', (tester) async {
    await openProfile(tester, {
      'required': true,
      'connected': true,
      'ready': true,
      'fee_percent': 12.5,
    });
    await tester.scrollUntilVisible(
      find.text('Ver meus recebimentos'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Recebimentos ativos'), findsOneWidget);
    expect(find.textContaining('12.5%'), findsOneWidget);
  });

  testWidgets('without real payments there is nothing to set up', (tester) async {
    await openProfile(tester, {
      'required': false,
      'connected': false,
      'ready': false,
      'fee_percent': 15.0,
    });
    expect(find.text('Seu perfil de anfitrião'), findsOneWidget);
    expect(find.text('Configure seus recebimentos', skipOffstage: false), findsNothing);
  });
}
