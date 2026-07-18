import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../booking/data/repositories.dart';

class HostSubscription {
  const HostSubscription({
    required this.plan,
    required this.status,
    required this.listingLimit,
    required this.responseHours,
    required this.features,
    this.requestedAt,
  });

  final String plan;
  final String status;
  final int listingLimit;
  final int responseHours;
  final List<String> features;
  final DateTime? requestedAt;

  bool get pro => plan == 'pro' && status == 'active';
  bool get pending => status == 'pending';

  factory HostSubscription.fromJson(Map<String, dynamic> json) =>
      HostSubscription(
        plan: json['plan']?.toString() ?? 'free',
        status: json['status']?.toString() ?? 'active',
        listingLimit: json['listing_limit'] as int,
        responseHours: json['response_hours'] as int,
        features: (json['features'] as List)
            .map((value) => value.toString())
            .toList(),
        requestedAt: json['requested_at'] == null
            ? null
            : DateTime.parse(json['requested_at'].toString()),
      );
}

class ManualRefund {
  const ManualRefund({
    required this.paymentId,
    required this.bookingId,
    required this.bookingReference,
    required this.parkingTitle,
    required this.renterName,
    required this.renterEmail,
    required this.amountCents,
    required this.currency,
    required this.paymentMethod,
    this.cancelledAt,
  });

  final String paymentId;
  final String bookingId;
  final String bookingReference;
  final String parkingTitle;
  final String renterName;
  final String renterEmail;
  final int amountCents;
  final String currency;
  final String paymentMethod;
  final DateTime? cancelledAt;

  factory ManualRefund.fromJson(Map<String, dynamic> json) => ManualRefund(
        paymentId: json['payment_id'].toString(),
        bookingId: json['booking_id'].toString(),
        bookingReference: json['booking_reference'].toString(),
        parkingTitle: json['parking_title'].toString(),
        renterName: json['renter_name'].toString(),
        renterEmail: json['renter_email'].toString(),
        amountCents: json['amount_cents'] as int,
        currency: json['currency']?.toString() ?? 'EUR',
        paymentMethod: json['payment_method']?.toString() ?? 'direct',
        cancelledAt: json['cancelled_at'] == null
            ? null
            : DateTime.parse(json['cancelled_at'].toString()),
      );
}

abstract interface class LaunchOperationsRepository {
  Future<HostSubscription> subscription();
  Future<HostSubscription> requestPro();
  Future<List<ManualRefund>> pendingRefunds();
  Future<void> completeRefund(
    String paymentId,
    String reference, {
    String? note,
  });
}

class ApiLaunchOperationsRepository implements LaunchOperationsRepository {
  const ApiLaunchOperationsRepository(this.api);

  final ApiClient api;

  @override
  Future<HostSubscription> subscription() async => HostSubscription.fromJson(
        await api.get('/host/subscription') as Map<String, dynamic>,
      );

  @override
  Future<HostSubscription> requestPro() async => HostSubscription.fromJson(
        await api.post('/host/subscription/request-pro')
            as Map<String, dynamic>,
      );

  @override
  Future<List<ManualRefund>> pendingRefunds() async =>
      (await api.get('/host/payments/direct/refunds') as List)
          .map(
            (value) => ManualRefund.fromJson(value as Map<String, dynamic>),
          )
          .toList();

  @override
  Future<void> completeRefund(
    String paymentId,
    String reference, {
    String? note,
  }) async {
    await api.post(
      '/host/payments/direct/$paymentId/refund',
      body: {
        'reference': reference.trim(),
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
      },
    );
  }
}

final launchOperationsRepositoryProvider = Provider<LaunchOperationsRepository>(
  (ref) => ApiLaunchOperationsRepository(ref.watch(apiClientProvider)),
);

String launchMoney(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';