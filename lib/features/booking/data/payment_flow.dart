import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../core/models/booking_model.dart';
import '../../../core/network/api_exception.dart';
import 'booking_repository.dart';

enum PaymentOutcome {
  /// Money taken (or nothing to take) — the booking is confirmed.
  paid,

  /// The user closed the payment sheet.
  cancelled,
}

/// Takes the payment for a pending booking through Stripe's payment sheet.
class PaymentFlow {
  PaymentFlow(this._repo);

  final BookingRepository _repo;

  Future<PaymentOutcome> pay(BookingModel booking) async {
    if (booking.status != BookingStatus.pending) return PaymentOutcome.paid;

    final config = await _repo.getPaymentConfig();
    if (!config.enabled || config.publishableKey == null) {
      throw ApiException(
        message: 'Pagamentos ainda não estão disponíveis. Tente mais tarde.',
      );
    }
    final clientSecret = await _repo.createPaymentIntent(booking.id);

    // The setter ignores an unchanged key. (Reading Stripe.publishableKey
    // before one was ever set throws, so don't compare against it.)
    Stripe.publishableKey = config.publishableKey!;
    await Stripe.instance.applySettings();
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'Acompanha',
        style: ThemeMode.light,
      ),
    );
    try {
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return PaymentOutcome.cancelled;
      throw ApiException(
        message: e.error.localizedMessage ?? 'O pagamento não foi aprovado.',
      );
    }

    final status = await _repo.capturePayment(booking.id);
    if (status != 'captured') {
      throw ApiException(
        message: 'O pagamento ainda está sendo processado. '
            'Confira em Reservas daqui a pouco.',
      );
    }
    return PaymentOutcome.paid;
  }
}
