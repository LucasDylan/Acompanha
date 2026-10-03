import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:projeto_apollo/features/booking/presentation/screens/booking_confirm_screen.dart';
import 'package:projeto_apollo/features/booking/presentation/screens/host_detail_screen.dart';
import 'package:projeto_apollo/features/bookings/presentation/screens/bookings_screen.dart';
import 'package:projeto_apollo/features/chat/presentation/screens/chat_screen.dart';
import 'package:projeto_apollo/features/discovery/presentation/widgets/host_card.dart';

import '../support/fake_api.dart';
import '../support/test_app.dart';

final _slotStart = DateTime.now().add(const Duration(days: 2)).toUtc();

Map<String, dynamic> _host() => {
      'id': '194',
      'user_id': '7',
      'display_name': 'Diego Ribeiro',
      'bio': 'Especialista em mentoria de carreira.',
      'avatar_url': null,
      'photos': <String>[],
      'categories': ['mentorship', 'networking'],
      'price_per_hour': 40.0,
      'currency': 'BRL',
      'rating': 4.8,
      'review_count': 12,
      // Not in the local city table, so no Google Map is built in the test.
      'location': 'Cidade Teste',
      'is_trainer': false,
      'is_active': true,
    };

Map<String, dynamic> _slot() => {
      'id': '55',
      'host_id': '194',
      'start_at': _slotStart.toIso8601String(),
      'end_at': _slotStart.add(const Duration(minutes: 90)).toIso8601String(),
      'status': 'available',
      'booking_id': null,
    };

Map<String, dynamic> _booking() => {
      'id': '900',
      'client_id': '1',
      'host_id': '194',
      'host_user_id': '7',
      'slot_id': '55',
      'status': 'confirmed',
      'amount': 60.0,
      'currency': 'BRL',
      'slot': _slot(),
      'host': _host(),
      'client': {'id': 1, 'display_name': 'Ana', 'avatar_url': null},
      'start_at': _slotStart.toIso8601String(),
      'end_at': _slotStart.add(const Duration(minutes: 90)).toIso8601String(),
      'payment_status': null,
      'cancelled_at': null,
      'cancelled_by_host': false,
      'refundable_if_cancelled': true,
      'review': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('filtering by a category tags the cards with it', (tester) async {
    usePhoneScreen(tester);
    final routes = <String, Handler>{
      'GET /profiles/hosts/': (_) => jsonResponse({
            'count': 1,
            'next': null,
            'previous': null,
            'results': [_host()],
          }),
    };
    signedIn(routes);
    await tester.pumpWidget(testApp(FakeApi(routes)));
    await settle(tester);

    Finder onCard(String text) =>
        find.descendant(of: find.byType(HostCard), matching: find.text(text));
    expect(onCard('Mentoria'), findsOneWidget); // the host's first category

    await tester.tap(find.text('Networking'));
    await settle(tester);
    expect(find.text('Trocar ideias e contatos na sua área.'), findsOneWidget);
    expect(onCard('Networking'), findsOneWidget);
    expect(onCard('Mentoria'), findsNothing);
  });

  testWidgets('book a slot, then message the host about it', (tester) async {
    usePhoneScreen(tester);
    var booked = false;
    final routes = <String, Handler>{
      'GET /profiles/hosts/': (_) => jsonResponse({
            'count': 1,
            'next': null,
            'previous': null,
            'results': [_host()],
          }),
      'GET /profiles/194/': (_) => jsonResponse(_host()),
      'GET /profiles/194/reviews/': (_) => jsonResponse({
            'count': 1,
            'next': null,
            'previous': null,
            'results': [
              {
                'id': 1,
                'rating': 5,
                'comment': 'Conversa excelente!',
                'author': 'Bia',
                'created_at': '2026-09-01T10:00:00Z',
              }
            ],
          }),
      'GET /profiles/194/slots/': (_) => jsonResponse([_slot()]),
      'GET /payments/config/': (_) => jsonResponse({
            'enabled': false,
            'publishable_key': null,
            'unpaid_bookings_allowed': true,
          }),
      'POST /bookings/': (req) {
        booked = req.data['slot_id'] == 55 && req.data['host_id'] == 194;
        return jsonResponse(_booking(), 201);
      },
      'GET /bookings/': (_) => jsonResponse({
            'count': 1,
            'next': null,
            'previous': null,
            'results': [_booking()],
          }),
      'GET /sessions/': (_) => jsonResponse(emptyPage()),
      'POST /conversations/': (_) => jsonResponse({
            'id': '3',
            'other_user': {'id': '7', 'display_name': 'Diego Ribeiro', 'avatar_url': null},
            'last_message': null,
            'unread_count': 0,
            'last_message_at': null,
          }),
      'GET /conversations/3/messages/': (_) => jsonResponse(<Object>[]),
      'POST /conversations/3/messages/': (req) => jsonResponse({
            'id': '1',
            'sender_id': '1',
            'text': req.data['text'],
            'created_at': DateTime.now().toUtc().toIso8601String(),
          }, 201),
    };
    signedIn(routes);
    await tester.pumpWidget(testApp(FakeApi(routes)));
    await settle(tester);

    // Discover → host page.
    await tester.tap(find.text('Diego Ribeiro'));
    await settle(tester);
    expect(find.byType(HostDetailScreen), findsOneWidget);
    final page = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Mentoria'), 300, scrollable: page);
    expect(
      find.text('Conselhos de carreira com quem já passou por isso.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Conversa excelente!'),
      300,
      scrollable: page,
    );
    // No fake verification claims on the page anymore.
    expect(find.textContaining('verificad', skipOffstage: false), findsNothing);
    expect(find.text('Online agora', skipOffstage: false), findsNothing);

    // Pick the 1h30 slot: R$ 40/h → R$ 60.
    await tester.tap(find.textContaining('Ver horários'));
    await settle(tester);
    expect(find.textContaining('1h30 · R\$ 60'), findsOneWidget);
    await tester.tap(find.textContaining('1h30'));
    await settle(tester);

    expect(find.byType(BookingConfirmScreen), findsOneWidget);
    expect(find.text('R\$ 60,00'), findsOneWidget);
    expect(find.textContaining('Modo de teste'), findsOneWidget);
    await tester.tap(find.text('Confirmar reserva').last); // the button, not the title
    await settle(tester);

    expect(booked, isTrue);
    expect(find.byType(BookingsScreen), findsOneWidget);
    expect(find.textContaining('Reserva confirmada com Diego Ribeiro'), findsOneWidget);
    expect(find.text('Confirmada'), findsOneWidget);

    // Message the host from the booking.
    await tester.tap(find.text('Mensagem'));
    await settle(tester);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.textContaining('Diga oi para Diego Ribeiro'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Oi! Onde nos encontramos?');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await settle(tester);
    // Sent: the composer is cleared and the text now lives in a bubble.
    final composer = tester.widget<TextField>(find.byType(TextField));
    expect(composer.controller!.text, isEmpty);
    expect(find.text('Oi! Onde nos encontramos?'), findsOneWidget);
    expect(find.text('Enviando…'), findsNothing);
  });

  testWidgets('cancelling explains the refund before doing it', (tester) async {
    usePhoneScreen(tester);
    var cancelled = false;
    final routes = <String, Handler>{
      'GET /profiles/hosts/': (_) => jsonResponse(emptyPage()),
      'GET /bookings/': (_) => jsonResponse({
            'count': 1,
            'next': null,
            'previous': null,
            'results': [
              {..._booking(), 'payment_status': 'captured'}
            ],
          }),
      'GET /sessions/': (_) => jsonResponse(emptyPage()),
      'POST /bookings/900/cancel/': (_) {
        cancelled = true;
        return jsonResponse({..._booking(), 'status': 'cancelled'});
      },
    };
    signedIn(routes);
    await tester.pumpWidget(testApp(FakeApi(routes)));
    await settle(tester);

    await tester.tap(find.text('Reservas'));
    await settle(tester);
    await tester.tap(find.text('Cancelar'));
    await settle(tester);

    expect(find.textContaining('R\$ 60,00 de volta'), findsOneWidget);
    await tester.tap(find.text('Cancelar reserva'));
    await settle(tester);
    expect(cancelled, isTrue);
  });
}
