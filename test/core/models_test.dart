import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:projeto_apollo/core/constants/category_meta.dart';
import 'package:projeto_apollo/core/models/booking_model.dart';
import 'package:projeto_apollo/core/models/slot_model.dart';
import 'package:projeto_apollo/core/network/api_exception.dart';
import 'package:projeto_apollo/core/utils/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test('money is formatted in Brazilian reais', () {
    expect(formatMoney(160, 'BRL'), 'R\$ 160,00');
    expect(formatMoney(120, 'BRL', compact: true), 'R\$ 120');
    expect(formatMoney(99.5, 'BRL', compact: true), 'R\$ 99,50');
  });

  test('durations read naturally', () {
    expect(formatDuration(45), '45 min');
    expect(formatDuration(60), '1h');
    expect(formatDuration(90), '1h30');
  });

  test('slots arrive in UTC and are shown in local time', () {
    final slot = SlotModel.fromJson({
      'id': 7,
      'host_id': 3,
      'start_at': '2030-01-10T12:00:00Z',
      'end_at': '2030-01-10T13:30:00Z',
      'status': 'available',
      'booking_id': null,
    });
    expect(slot.startAt.isUtc, isFalse);
    expect(slot.startAt.toUtc(), DateTime.utc(2030, 1, 10, 12));
    expect(slot.durationMinutes, 90);
    expect(slot.priceFor(80), 120);
    expect(slot.isAvailable, isTrue);
  });

  test('a past slot is never offered as available', () {
    final slot = SlotModel.fromJson({
      'id': 1,
      'host_id': 1,
      'start_at': '2020-01-10T12:00:00Z',
      'end_at': '2020-01-10T13:00:00Z',
      'status': 'available',
    });
    expect(slot.isAvailable, isFalse);
  });

  test('booking parses the fields the bookings screen relies on', () {
    final booking = BookingModel.fromJson({
      'id': '5',
      'client_id': '2',
      'host_id': '9',
      'host_user_id': '11',
      'slot_id': '4',
      'status': 'confirmed',
      'amount': 160.0,
      'currency': 'BRL',
      'start_at': '2099-01-10T12:00:00Z',
      'end_at': '2099-01-10T14:00:00Z',
      'payment_status': 'captured',
      'refundable_if_cancelled': true,
      'cancelled_by_host': false,
      'client': {'id': 2, 'display_name': 'Bia', 'avatar_url': null},
      'review': null,
    });
    expect(booking.amountLabel, 'R\$ 160,00');
    expect(booking.canCancel, isTrue);
    expect(booking.canReview, isFalse);
    expect(booking.hostUserId, '11');
    expect(booking.client!.name, 'Bia');
  });

  test('category slugs map to Portuguese labels', () {
    expect(categoryLabel('coffee'), 'Café');
    expect(categoryLabel('workout'), 'Treino');
    expect(categoryLabel('unknown'), 'unknown');
  });

  test('API errors surface the field message the server sent', () {
    final e = ApiException.fromDio(DioException(
      requestOptions: RequestOptions(path: '/auth/register/'),
      response: Response(
        requestOptions: RequestOptions(path: '/auth/register/'),
        statusCode: 400,
        data: {
          'email': ['Já existe uma conta com este e-mail.'],
        },
      ),
    ));
    expect(e.message, 'Já existe uma conta com este e-mail.');
    expect(e.fieldError('email'), 'Já existe uma conta com este e-mail.');
  });
}
