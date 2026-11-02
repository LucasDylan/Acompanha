import 'package:dio/dio.dart' show ResponseBody;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:projeto_apollo/features/booking/presentation/screens/host_detail_screen.dart';
import 'package:projeto_apollo/features/chat/presentation/screens/chat_screen.dart';

import '../support/fake_api.dart';
import '../support/test_app.dart';

Map<String, dynamic> _conversation() => {
      'id': '1',
      'other_user': {'id': '10', 'display_name': 'Bruno Lima', 'avatar_url': null},
      'last_message': {
        'id': '5',
        'sender_id': '10',
        'text': 'Bora amanhã às 7h?',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      'unread_count': 0,
      'last_message_at': DateTime.now().toUtc().toIso8601String(),
    };

Map<String, dynamic> _host() => {
      'id': '194',
      'user_id': '7',
      'display_name': 'Diego Ribeiro',
      'bio': 'Mentoria de carreira.',
      'avatar_url': null,
      'photos': <String>[],
      'categories': ['mentorship'],
      'price_per_hour': 40.0,
      'currency': 'BRL',
      'rating': null,
      'review_count': 0,
      'location': 'Cidade Teste',
      'is_trainer': false,
      'is_active': true,
    };

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('blocking someone from the chat closes it and empties the inbox',
      (tester) async {
    usePhoneScreen(tester);
    var blocked = false;
    final routes = <String, Handler>{
      'GET /profiles/hosts/': (_) => jsonResponse(emptyPage()),
      'GET /conversations/': (_) => jsonResponse(blocked ? [] : [_conversation()]),
      'GET /conversations/1/': (_) => jsonResponse(_conversation()),
      'GET /conversations/1/messages/': (_) => jsonResponse([]),
      'POST /blocks/': (_) {
        blocked = true;
        return jsonResponse({
          'user_id': 10,
          'display_name': 'Bruno Lima',
          'avatar_url': null,
          'blocked_at': DateTime.now().toUtc().toIso8601String(),
        }, 201);
      },
    };
    signedIn(routes);
    final api = FakeApi(routes);
    await tester.pumpWidget(testApp(api));
    await settle(tester);

    await tester.tap(find.text('Mensagens'));
    await settle(tester);
    await tester.tap(find.text('Bruno Lima'));
    await settle(tester);
    expect(find.byType(ChatScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Mais opções'));
    await settle(tester);
    await tester.tap(find.text('Bloquear'));
    await settle(tester);
    expect(find.text('Bloquear Bruno Lima?'), findsOneWidget);
    await tester.tap(find.text('Bloquear'));
    await settle(tester);

    expect(api.count('POST /blocks/'), 1);
    expect(api.requests.firstWhere((r) => r.path == '/blocks/').data['user_id'], 10);
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.text('Você bloqueou Bruno Lima.'), findsOneWidget);
    expect(find.text('Bora amanhã às 7h?'), findsNothing); // gone from the inbox
  });

  testWidgets('reporting a host sends the reason and blocks them by default',
      (tester) async {
    usePhoneScreen(tester);
    final routes = <String, Handler>{
      'GET /profiles/hosts/': (_) => jsonResponse({
            'count': 1,
            'next': null,
            'previous': null,
            'results': [_host()],
          }),
      'GET /profiles/194/': (_) => jsonResponse(_host()),
      'GET /profiles/194/reviews/': (_) => jsonResponse(emptyPage()),
      'GET /profiles/194/slots/': (_) => jsonResponse([]),
      'POST /reports/': (_) => jsonResponse({'id': 1, 'blocked': true}, 201),
    };
    signedIn(routes);
    final api = FakeApi(routes);
    await tester.pumpWidget(testApp(api));
    await settle(tester);

    await tester.tap(find.text('Diego Ribeiro'));
    await settle(tester);
    expect(find.byType(HostDetailScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Mais opções'));
    await settle(tester);
    await tester.tap(find.text('Denunciar'));
    await settle(tester);
    expect(find.text('Denunciar Diego Ribeiro'), findsOneWidget);
    await tester.tap(find.text('Perfil falso'));
    await tester.enterText(find.byType(TextField), 'Fotos de outra pessoa.');
    await tester.tap(find.text('Enviar denúncia'));
    await settle(tester);

    final body = api.requests.firstWhere((r) => r.path == '/reports/').data as Map;
    expect(body['user_id'], 7);
    expect(body['reason'], 'fake');
    expect(body['details'], 'Fotos de outra pessoa.');
    expect(body['block'], isTrue);
    expect(find.byType(HostDetailScreen), findsNothing); // blocked: page closed
    expect(find.textContaining('Denúncia enviada'), findsOneWidget);
  });

  testWidgets('blocked people are listed in Privacy and can be unblocked',
      (tester) async {
    usePhoneScreen(tester);
    var people = [
      {'user_id': 12, 'display_name': 'Bia', 'avatar_url': null, 'blocked_at': '2026-10-01T10:00:00Z'},
    ];
    final routes = <String, Handler>{
      'GET /profiles/hosts/': (_) => jsonResponse(emptyPage()),
      'GET /profiles/me/': (_) => jsonResponse({'detail': 'none'}, 404),
      'GET /blocks/': (_) => jsonResponse(people),
      'DELETE /blocks/12/': (_) {
        people = [];
        return ResponseBody.fromString('', 204);
      },
    };
    signedIn(routes);
    final api = FakeApi(routes);
    await tester.pumpWidget(testApp(api));
    await settle(tester);

    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/privacy');
    await settle(tester);

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Desbloquear'), 300, scrollable: list);
    expect(find.text('Bia'), findsOneWidget);
    await tester.tap(find.text('Desbloquear'));
    await settle(tester);

    expect(api.count('DELETE /blocks/12/'), 1);
    expect(find.text('Você desbloqueou Bia.'), findsOneWidget);
    expect(find.textContaining('Você não bloqueou ninguém'), findsOneWidget);
  });
}
