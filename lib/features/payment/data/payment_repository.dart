import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../parking/data/providers.dart';
import '../../booking/data/repositories.dart';

class PaymentCheckoutResult {
  const PaymentCheckoutResult({
    required this.bookingId,
    required this.requiresRedirect,
    required this.status,
    this.checkoutUrl,
    this.sessionId,
  });

  final String bookingId;
  final bool requiresRedirect;
  final String status;
  final String? checkoutUrl;
  final String? sessionId;

  factory PaymentCheckoutResult.fromJson(Map<String, dynamic> json) {
    final payment = json['payment'] as Map<String, dynamic>;
    return PaymentCheckoutResult(
      bookingId: json['booking_id'].toString(),
      requiresRedirect: json['requires_redirect'] == true,
      status: payment['status']?.toString() ?? 'pending',
      checkoutUrl: payment['checkout_url']?.toString(),
      sessionId: payment['checkout_session_id']?.toString(),
    );
  }
}

class ConnectStatus {
  const ConnectStatus({
    required this.mode,
    required this.configured,
    required this.connected,
    required this.detailsSubmitted,
    required this.chargesEnabled,
    required this.payoutsEnabled,
  });

  final String mode;
  final bool configured;
  final bool connected;
  final bool detailsSubmitted;
  final bool chargesEnabled;
  final bool payoutsEnabled;

  bool get ready => chargesEnabled && payoutsEnabled;

  factory ConnectStatus.fromJson(Map<String, dynamic> json) => ConnectStatus(
        mode: json['mode']?.toString() ?? 'beta',
        configured: json['configured'] == true,
        connected: json['connected'] == true,
        detailsSubmitted: json['details_submitted'] == true,
        chargesEnabled: json['charges_enabled'] == true,
        payoutsEnabled: json['payouts_enabled'] == true,
      );
}

class HostFinanceTransaction {
  const HostFinanceTransaction({
    required this.id,
    required this.bookingId,
    required this.status,
    required this.amountCents,
    required this.platformFeeCents,
    required this.hostNetCents,
    required this.currency,
    this.paidAt,
    this.refundedAt,
  });

  final String id;
  final String bookingId;
  final String status;
  final int amountCents;
  final int platformFeeCents;
  final int hostNetCents;
  final String currency;
  final DateTime? paidAt;
  final DateTime? refundedAt;

  factory HostFinanceTransaction.fromJson(Map<String, dynamic> json) =>
      HostFinanceTransaction(
        id: json['id'].toString(),
        bookingId: json['booking_id'].toString(),
        status: json['status'].toString(),
        amountCents: json['amount_cents'] as int,
        platformFeeCents: json['platform_fee_cents'] as int,
        hostNetCents: json['host_net_cents'] as int,
        currency: json['currency']?.toString() ?? 'EUR',
        paidAt: json['paid_at'] == null
            ? null
            : DateTime.parse(json['paid_at'].toString()),
        refundedAt: json['refunded_at'] == null
            ? null
            : DateTime.parse(json['refunded_at'].toString()),
      );
}

class HostFinanceSnapshot {
  const HostFinanceSnapshot({
    required this.grossPaidCents,
    required this.platformFeeCents,
    required this.hostNetCents,
    required this.pendingCents,
    required this.refundedCents,
    required this.connect,
    required this.transactions,
  });

  final int grossPaidCents;
  final int platformFeeCents;
  final int hostNetCents;
  final int pendingCents;
  final int refundedCents;
  final ConnectStatus connect;
  final List<HostFinanceTransaction> transactions;

  factory HostFinanceSnapshot.fromJson(Map<String, dynamic> json) =>
      HostFinanceSnapshot(
        grossPaidCents: json['gross_paid_cents'] as int,
        platformFeeCents: json['platform_fee_cents'] as int,
        hostNetCents: json['host_net_cents'] as int,
        pendingCents: json['pending_cents'] as int,
        refundedCents: json['refunded_cents'] as int,
        connect: ConnectStatus.fromJson(
          json['connect'] as Map<String, dynamic>,
        ),
        transactions: (json['transactions'] as List)
            .map(
              (value) => HostFinanceTransaction.fromJson(
                value as Map<String, dynamic>,
              ),
            )
            .toList(),
      );
}

abstract interface class PaymentRepository {
  Future<PaymentCheckoutResult> createCheckout(BookingRecord booking);
  Future<PaymentCheckoutResult> checkoutStatus(String sessionId);
  Future<HostFinanceSnapshot> finance();
  Future<ConnectStatus> connectStatus();
  Future<Uri> onboardingLink();
  Future<Uri> dashboardLink();
}

class ApiPaymentRepository implements PaymentRepository {
  const ApiPaymentRepository(this.api);

  final ApiClient api;

  @override
  Future<PaymentCheckoutResult> createCheckout(BookingRecord booking) async =>
      PaymentCheckoutResult.fromJson(
        await api.post(
          '/payments/checkout',
          body: {
            'parking_space_id': booking.parkingId,
            'vehicle_id': booking.vehicleId,
            'start_at': booking.start.toIso8601String(),
            'end_at': booking.end.toIso8601String(),
            'idempotency_key': createBookingIdempotencyKey(),
          },
        ) as Map<String, dynamic>,
      );

  @override
  Future<PaymentCheckoutResult> checkoutStatus(String sessionId) async {
    final json = await api.get('/payments/checkout/$sessionId')
        as Map<String, dynamic>;
    final payment = json['payment'] as Map<String, dynamic>;
    return PaymentCheckoutResult(
      bookingId: json['booking_id'].toString(),
      requiresRedirect: false,
      status: payment['status']?.toString() ?? 'pending',
      checkoutUrl: payment['checkout_url']?.toString(),
      sessionId: payment['checkout_session_id']?.toString(),
    );
  }

  @override
  Future<HostFinanceSnapshot> finance() async => HostFinanceSnapshot.fromJson(
        await api.get('/host/finance') as Map<String, dynamic>,
      );

  @override
  Future<ConnectStatus> connectStatus() async => ConnectStatus.fromJson(
        await api.get('/host/payments/connect/status')
            as Map<String, dynamic>,
      );

  @override
  Future<Uri> onboardingLink() async {
    final json = await api.post('/host/payments/connect/onboarding')
        as Map<String, dynamic>;
    return Uri.parse(json['url'].toString());
  }

  @override
  Future<Uri> dashboardLink() async {
    final json = await api.post('/host/payments/connect/dashboard')
        as Map<String, dynamic>;
    return Uri.parse(json['url'].toString());
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => ApiPaymentRepository(ref.watch(apiClientProvider)),
);
