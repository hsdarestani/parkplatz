import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/core/network/api_client.dart';
import 'package:freiraum_parking/features/booking/data/repositories.dart';
import 'package:freiraum_parking/features/payment/data/payment_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TokenStore implements ApiTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAccess() async => 'access';

  @override
  Future<String?> readRefresh() async => null;

  @override
  Future<void> save(String access, String refresh) async {}
}

void main() {
  test('checkout response preserves redirect and booking identifiers', () async {
    final repository = ApiPaymentRepository(
      ApiClient(
        _TokenStore(),
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'requires_redirect': true,
              'booking_id': 'booking-1',
              'payment': {
                'status': 'checkout_created',
                'checkout_url': 'https://checkout.stripe.com/example',
                'checkout_session_id': 'cs_test_1',
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          ),
        ),
      ),
    );

    final result = await repository.createCheckout(
      BookingRecord(
        id: 'draft',
        parkingId: 'space-1',
        title: 'Test',
        reference: 'FR-TEST',
        vehicleId: 'vehicle-1',
        plate: 'F-TEST 1',
        status: 'pending',
        start: DateTime(2026, 7, 20, 10),
        end: DateTime(2026, 7, 20, 12),
        totalCents: 700,
      ),
    );

    expect(result.bookingId, 'booking-1');
    expect(result.requiresRedirect, isTrue);
    expect(result.status, 'checkout_created');
    expect(result.sessionId, 'cs_test_1');
  });

  test('direct checkout includes owner destination and booking reference', () {
    final result = PaymentCheckoutResult.fromJson({
      'requires_redirect': false,
      'booking_id': 'booking-direct',
      'payment': {'status': 'awaiting_payment'},
      'direct_payment': {
        'method': 'paypal',
        'payment_url': 'https://paypal.me/example',
        'payment_reference': 'FR-ABC123',
        'amount_cents': 900,
        'currency': 'EUR',
      },
    });

    expect(result.requiresRedirect, isFalse);
    expect(result.status, 'awaiting_payment');
    expect(result.directPayment?.method, 'paypal');
    expect(result.directPayment?.paymentReference, 'FR-ABC123');
    expect(result.directPayment?.amountCents, 900);
  });

  test('direct settings serialize only normalized payment fields', () {
    const settings = DirectPaymentSettings(
      method: 'sepa',
      enabled: true,
      configured: true,
      iban: 'DE12 3456 7890 1234 5678 90',
      accountHolder: '  Max Mustermann  ',
      instructions: '  Use the booking reference.  ',
    );

    final json = settings.toJson();

    expect(json['method'], 'sepa');
    expect(json['iban'], 'DE12345678901234567890');
    expect(json['account_holder'], 'Max Mustermann');
    expect(json['instructions'], 'Use the booking reference.');
    expect(json['enabled'], isTrue);
  });

  test('connect status is ready only when charges and payouts are enabled', () {
    final ready = ConnectStatus.fromJson({
      'mode': 'stripe',
      'configured': true,
      'connected': true,
      'details_submitted': true,
      'charges_enabled': true,
      'payouts_enabled': true,
    });
    final incomplete = ConnectStatus.fromJson({
      'mode': 'stripe',
      'configured': true,
      'connected': true,
      'details_submitted': false,
      'charges_enabled': true,
      'payouts_enabled': false,
    });

    expect(ready.ready, isTrue);
    expect(incomplete.ready, isFalse);
  });
}
