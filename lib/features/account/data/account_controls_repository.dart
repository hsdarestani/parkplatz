import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../booking/data/repositories.dart';

class NotificationPreferences {
  const NotificationPreferences({
    required this.bookingUpdates,
    required this.hostUpdates,
    required this.trustUpdates,
    required this.securityUpdates,
    required this.marketing,
  });

  final bool bookingUpdates;
  final bool hostUpdates;
  final bool trustUpdates;
  final bool securityUpdates;
  final bool marketing;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        bookingUpdates: json['booking_updates'] != false,
        hostUpdates: json['host_updates'] != false,
        trustUpdates: json['trust_updates'] != false,
        securityUpdates: json['security_updates'] != false,
        marketing: json['marketing'] == true,
      );

  Map<String, dynamic> toJson() => {
        'booking_updates': bookingUpdates,
        'host_updates': hostUpdates,
        'trust_updates': trustUpdates,
        'security_updates': securityUpdates,
        'marketing': marketing,
      };

  NotificationPreferences copyWith({
    bool? bookingUpdates,
    bool? hostUpdates,
    bool? trustUpdates,
    bool? securityUpdates,
    bool? marketing,
  }) =>
      NotificationPreferences(
        bookingUpdates: bookingUpdates ?? this.bookingUpdates,
        hostUpdates: hostUpdates ?? this.hostUpdates,
        trustUpdates: trustUpdates ?? this.trustUpdates,
        securityUpdates: securityUpdates ?? this.securityUpdates,
        marketing: marketing ?? this.marketing,
      );
}

abstract interface class AccountControlsRepository {
  Future<void> requestPasswordReset(String email);
  Future<void> resetPassword(String token, String newPassword);
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<NotificationPreferences> notificationPreferences();
  Future<NotificationPreferences> saveNotificationPreferences(
    NotificationPreferences value,
  );
  Future<Map<String, dynamic>> exportData();
  Future<void> deleteAccount(String password);
}

class ApiAccountControlsRepository implements AccountControlsRepository {
  const ApiAccountControlsRepository(this.api);

  final ApiClient api;

  @override
  Future<void> requestPasswordReset(String email) async {
    await api.post(
      '/auth/password/forgot',
      body: {'email': email.trim()},
      authenticated: false,
    );
  }

  @override
  Future<void> resetPassword(String token, String newPassword) async {
    await api.post(
      '/auth/password/reset',
      body: {'token': token, 'new_password': newPassword},
      authenticated: false,
    );
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await api.post(
      '/account/password',
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  @override
  Future<NotificationPreferences> notificationPreferences() async =>
      NotificationPreferences.fromJson(
        await api.get('/account/notifications') as Map<String, dynamic>,
      );

  @override
  Future<NotificationPreferences> saveNotificationPreferences(
    NotificationPreferences value,
  ) async =>
      NotificationPreferences.fromJson(
        await api.patch(
          '/account/notifications',
          body: value.toJson(),
        ) as Map<String, dynamic>,
      );

  @override
  Future<Map<String, dynamic>> exportData() async =>
      await api.get('/account/export') as Map<String, dynamic>;

  @override
  Future<void> deleteAccount(String password) async {
    await api.post(
      '/account/delete',
      body: {'password': password, 'confirmation': 'DELETE'},
    );
  }
}

class LocalAccountControlsRepository implements AccountControlsRepository {
  const LocalAccountControlsRepository();

  static const defaults = NotificationPreferences(
    bookingUpdates: true,
    hostUpdates: true,
    trustUpdates: true,
    securityUpdates: true,
    marketing: false,
  );

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> resetPassword(String token, String newPassword) async {}

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {}

  @override
  Future<NotificationPreferences> notificationPreferences() async => defaults;

  @override
  Future<NotificationPreferences> saveNotificationPreferences(
    NotificationPreferences value,
  ) async => value;

  @override
  Future<Map<String, dynamic>> exportData() async => {
        'mode': 'local_beta',
        'message': 'Lokale Beta-Daten bleiben auf diesem Gerät.',
      };

  @override
  Future<void> deleteAccount(String password) async {}
}

final accountControlsRepositoryProvider = Provider<AccountControlsRepository>((ref) {
  final mode = ref.watch(appModeProvider);
  if (mode == AppMode.localBeta) return const LocalAccountControlsRepository();
  return ApiAccountControlsRepository(ref.watch(apiClientProvider));
});