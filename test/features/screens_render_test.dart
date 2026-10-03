import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../support/fake_api.dart';
import '../support/test_app.dart';

/// Every tab and the profile sub-screens render on a phone-sized screen
/// against realistic API data, without layout errors.
void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  Map<String, Handler> routes() => {
        'GET /profiles/hosts/': (_) => jsonResponse(emptyPage()),
        'GET /profiles/me/': (_) => jsonResponse({'detail': 'none'}, 404),
        'GET /gym-members/': (_) => jsonResponse({
              'count': 2,
              'next': null,
              'previous': null,
              'results': [
                {
                  'id': 10,
                  'display_name': 'Bruno Lima',
                  'avatar_url': null,
                  'gym': {'id': 1, 'name': 'Smart Fit Paulista'},
                  'fitness_level': 'advanced',
                  'workout_types': ['Musculação', 'CrossFit'],
                  'available_days': ['Seg', 'Qua'],
                  'bio': 'Foco em hipertrofia.',
                  'age': 29,
                  'match_status': 'received',
                },
                {
                  'id': 11,
                  'display_name': 'Carla Souza',
                  'avatar_url': null,
                  'gym': {'id': 1, 'name': 'Smart Fit Paulista'},
                  'fitness_level': 'beginner',
                  'workout_types': <String>[],
                  'available_days': <String>[],
                  'bio': '',
                  'age': null,
                  'match_status': 'matched',
                },
              ],
            }),
        'GET /matches/incoming/': (_) => jsonResponse(emptyPage()),
        'GET /matches/': (_) => jsonResponse(emptyPage()),
        'GET /bookings/': (_) => jsonResponse(emptyPage()),
        'GET /sessions/': (_) => jsonResponse(emptyPage()),
        'GET /conversations/': (_) => jsonResponse([
              {
                'id': '1',
                'other_user': {'id': '10', 'display_name': 'Bruno Lima', 'avatar_url': null},
                'last_message': {
                  'id': '5',
                  'sender_id': '10',
                  'text': 'Bora amanhã às 7h?',
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                },
                'unread_count': 2,
                'last_message_at': DateTime.now().toUtc().toIso8601String(),
              }
            ]),
      };

  testWidgets('all tabs and profile screens render', (tester) async {
    usePhoneScreen(tester);
    final r = routes();
    final user = {
      ...userJson(),
      'gym': {'id': 1, 'name': 'Smart Fit Paulista'},
    };
    signedIn(r, user: user);
    await tester.pumpWidget(testApp(FakeApi(r)));
    await settle(tester);

    await tester.tap(find.text('Parceiros'));
    await settle(tester);
    expect(find.text('Bruno Lima, 29'), findsOneWidget);
    expect(find.text('Aceitar'), findsOneWidget); // they asked first
    expect(find.text('Mensagem'), findsOneWidget); // already partners

    await tester.tap(find.text('Mensagens'));
    await settle(tester);
    expect(find.text('Bora amanhã às 7h?'), findsOneWidget);

    await tester.tap(find.text('Reservas'));
    await settle(tester);
    expect(find.text('Nenhuma reserva ainda'), findsOneWidget);

    await tester.tap(find.text('Perfil'));
    await settle(tester);
    expect(find.text('Seja um anfitrião'), findsOneWidget);
    // The old dead menu items are gone.
    expect(find.text('Formas de pagamento'), findsNothing);
    expect(find.text('Notificações'), findsNothing);

    await tester.ensureVisible(find.text('Editar meu perfil'));
    await tester.tap(find.text('Editar meu perfil'));
    await settle(tester);
    expect(find.text('Nível de treino'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await settle(tester);

    await tester.ensureVisible(find.text('Ajuda'));
    await tester.tap(find.text('Ajuda'));
    await settle(tester);
    expect(find.text('Perguntas frequentes'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await settle(tester);

    await tester.ensureVisible(find.text('Privacidade e segurança'));
    await tester.tap(find.text('Privacidade e segurança'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Excluir minha conta'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Voltar'));
    await settle(tester);

    await tester.ensureVisible(find.text('Criar perfil de anfitrião'));
    await tester.tap(find.text('Criar perfil de anfitrião'));
    await settle(tester);
    expect(find.text('Tipos de encontro'), findsOneWidget);
    expect(find.byType(FilterChip), findsNWidgets(7));
  });
}
