import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../booking/data/repositories.dart';

class DirectPaymentInstructions {
  const DirectPaymentInstructions({
    required this.method,
    required this.paymentReference,
    required this.amountCents,
    required this.currency,
    this.paymentUrl,
    this.iban,
    this.accountHolder,
    this.instructions,
  });

  final String method;
  final String paymentReference;
  final int amountCents;
  final String currency;
  final String? paymentUrl;
  final String? iban;
  final String? accountHolder;
  final String? instructions;

  factory DirectPaymentInstructions.fromJson(Map<String, dynamic> json) =>
      DirectPaymentInstructions(
        method: json['method']?.toString() ?? 'paypal',
        paymentReference: json['payment_reference']?.toString() ?? '',
        amountCents: json['amount_cents'] as int,
        currency: json['currency']?.toString() ?? 'EUR',
        paymentUrl: json['payment_url']?.toString(),
        iban: json['iban']?.toString(),
        accountHolder: json['account_holder']?.toString(),
        instructions: json['instructions']?.toString(),
      );
}

class PaymentCheckoutResult {
  const PaymentCheckoutResult({
    required this.bookingId,
    required this.requiresRedirect,
    required this.status,
    this.checkoutUrl,
    this.sessionId,
    this.directPayment,
  });

  final String bookingId;
  final bool requiresRedirect;
  final String status;
  final String? checkoutUrl;
  final String? sessionId;
  final DirectPaymentInstructions? directPayment;

  factory PaymentCheckoutResult.fromJson(Map<String, dynamic> json) {
    final payment = json['payment'] as Map<String, dynamic>;
    final direct = json['direct_payment'];
    return PaymentCheckoutResult(
      bookingId: json['booking_id'].toString(),
      requiresRedirect: json['requires_redirect'] == true,
      status: payment['status']?.toString() ?? 'pending',
      checkoutUrl: payment['checkout_url']?.toString(),
      sessionId: payment['checkout_session_id']?.toString(),
      directPayment: direct is Map<String, dynamic>
          ? DirectPaymentInstructions.fromJson(direct)
          : null,
    );
  }
}

class DirectPaymentSettings {
  const DirectPaymentSettings({
    required this.method,
    required this.enabled,
    required this.configured,
    this.paymentUrl,
    this.iban,
    this.accountHolder,
    this.instructions,
  });

  final String method;
  final bool enabled;
  final bool configured;
  final String? paymentUrl;
  final String? iban;
  final String? accountHolder;
  final String? instructions;

  factory DirectPaymentSettings.fromJson(Map<String, dynamic> json) =>
      DirectPaymentSettings(
        method: json['method']?.toString() ?? 'paypal',
        enabled: json['enabled'] == true,
        configured: json['configured'] == true,
        paymentUrl: json['payment_url']?.toString(),
        iban: json['iban']?.toString(),
        accountHolder: json['account_holder']?.toString(),
        instructions: json['instructions']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'method': method,
        'payment_url': paymentUrl?.trim().isEmpty == true ? null : paymentUrl?.trim(),
        'iban': iban?.replaceAll(' ', '').trim().isEmpty == true
            ? null
            : iban?.replaceAll(' ', '').trim(),
        'account_holder': accountHolder?.trim().isEmpty == true
            ? null
            : accountHolder?.trim(),
        'instructions': instructions?.trim().isEmpty == true
            ? null
            : instructions?.trim(),
        'enabled': enabled,
      };
}

class PendingDirectPayment {
  const PendingDirectPayment({
    required this.paymentId,
    required this.bookingId,
    required this.bookingReference,
    required this.parkingTitle,
    required this.renterName,
    required this.renterEmail,
    required this.vehiclePlate,
    required this.start,
    required this.end,
    required this.amountCents,
    required this.currency,
    required this.paymentMethod,
    required this.payerReference,
    required this.submittedAt,
  });

  final String paymentId;
  final String bookingId;
  final String bookingReference;
  final String parkingTitle;
  final String renterName;
  final String renterEmail;
  final String vehiclePlate;
  final DateTime start;
  final DateTime end;
  final int amountCents;
  final String currency;
  final String paymentMethod;
  final String payerReference;
  final DateTime submittedAt;

  factory PendingDirectPayment.fromJson(Map<String, dynamic> json) =>
      PendingDirectPayment(
        paymentId: json['payment_id'].toString(),
        bookingId: json['booking_id'].toString(),
        bookingReference: json['booking_reference'].toString(),
        parkingTitle: json['parking_title'].toString(),
        renterName: json['renter_name'].toString(),
        renterEmail: json['renter_email'].toString(),
        vehiclePlate: json['vehicle_plate'].toString(),
        start: DateTime.parse(json['start_at'].toString()),
        end: DateTime.parse(json['end_at'].toString()),
        amountCents: json['amount_cents'] as int,
        currency: json['currency']?.toString() ?? 'EUR',
        paymentMethod: json['payment_method']?.toString() ?? 'direct',
        payerReference: json['payer_reference']?.toString() ?? '',
        submittedAt: DateTime.parse(json['submitted_at'].toString()),
      );
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
  Future<void> submitDirectReference(String bookingId, String reference);
  Future<DirectPaymentSettings> directSettings();
  Future<DirectPaymentSettings> saveDirectSettings(
    DirectPaymentSettings settings,
  );
  Future<List<PendingDirectPayment>> pendingDirectPayments();
  Future<void> decideDirectPayment(
    String paymentId,
    String decision, {
    String? reason,
  });
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
  Future<void> submitDirectReference(String bookingId, String reference) async {
    await api.post(
      '/payments/bookings/$bookingId/reference',
      body: {'reference': reference.trim()},
    );
  }

  @override
  Future<DirectPaymentSettings> directSettings() async =>
      DirectPaymentSettings.fromJson(
        await api.get('/host/payments/direct/settings')
            as Map<String, dynamic>,
      );

  @override
  Future<DirectPaymentSettings> saveDirectSettings(
    DirectPaymentSettings settings,
  ) async =>
      DirectPaymentSettings.fromJson(
        await api.post(
          '/host/payments/direct/settings',
          body: settings.toJson(),
        ) as Map<String, dynamic>,
      );

  @override
  Future<List<PendingDirectPayment>> pendingDirectPayments() async =>
      (await api.get('/host/payments/direct/pending') as List)
          .map(
            (value) => PendingDirectPayment.fromJson(
              value as Map<String, dynamic>,
            ),
          )
          .toList();

  @override
  Future<void> decideDirectPayment(
    String paymentId,
    String decision, {
    String? reason,
  }) async {
    await api.post(
      '/host/payments/direct/$paymentId/decision',
      body: {
        'decision': decision,
        'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
      },
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
