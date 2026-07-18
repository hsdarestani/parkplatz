import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/payment/data/launch_operations_repository.dart';
import 'package:freiraum_parking/features/payment/data/payment_repository.dart';

void main() {
  test('host subscription parses free and pro limits', () {
    final free = HostSubscription.fromJson({
      'plan': 'free',
      'status': 'active',
      'listing_limit': 1,
      'response_hours': 12,
      'features': ['Ein aktiver Stellplatz'],
    });
    final pro = HostSubscription.fromJson({
      'plan': 'pro',
      'status': 'active',
      'listing_limit': 10,
      'response_hours': 6,
      'features': ['Bis zu 10 aktive Stellplätze'],
    });

    expect(free.pro, isFalse);
    expect(free.listingLimit, 1);
    expect(pro.pro, isTrue);
    expect(pro.responseHours, 6);
  });

  test('pending direct payment preserves receipt and response deadline', () {
    final payment = PendingDirectPayment.fromJson({
      'payment_id': 'payment-1',
      'booking_id': 'booking-1',
      'booking_reference': 'FR-TEST',
      'parking_title': 'Testplatz',
      'renter_name': 'Alex',
      'renter_email': 'alex@example.com',
      'vehicle_plate': 'F-AB 123',
      'start_at': '2026-07-20T10:00:00Z',
      'end_at': '2026-07-20T12:00:00Z',
      'amount_cents': 900,
      'currency': 'EUR',
      'payment_method': 'paypal',
      'payer_reference': 'TX-123',
      'submitted_at': '2026-07-19T10:00:00Z',
      'host_response_due_at': '2026-07-19T22:00:00Z',
      'receipt_url': 'https://example.com/receipt',
      'receipt_original_name': 'receipt.pdf',
    });

    expect(payment.responseDueAt, isNotNull);
    expect(payment.receiptOriginalName, 'receipt.pdf');
    expect(payment.receiptUrl, contains('receipt'));
  });

  test('manual refund preserves renter and payment details', () {
    final refund = ManualRefund.fromJson({
      'payment_id': 'payment-1',
      'booking_id': 'booking-1',
      'booking_reference': 'FR-TEST',
      'parking_title': 'Testplatz',
      'renter_name': 'Alex',
      'renter_email': 'alex@example.com',
      'amount_cents': 900,
      'currency': 'EUR',
      'payment_method': 'paypal',
      'cancelled_at': '2026-07-19T12:00:00Z',
    });

    expect(refund.amountCents, 900);
    expect(refund.paymentMethod, 'paypal');
    expect(refund.cancelledAt, isNotNull);
  });
}
