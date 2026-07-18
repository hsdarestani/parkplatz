import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/account/data/account_controls_repository.dart';

void main() {
  test('notification preferences parse safe transactional defaults', () {
    final value = NotificationPreferences.fromJson(const {});

    expect(value.bookingUpdates, isTrue);
    expect(value.hostUpdates, isTrue);
    expect(value.trustUpdates, isTrue);
    expect(value.securityUpdates, isTrue);
    expect(value.marketing, isFalse);
  });

  test('notification preferences serialize exact API fields', () {
    const value = NotificationPreferences(
      bookingUpdates: false,
      hostUpdates: true,
      trustUpdates: false,
      securityUpdates: true,
      marketing: true,
    );

    expect(
      value.toJson(),
      {
        'booking_updates': false,
        'host_updates': true,
        'trust_updates': false,
        'security_updates': true,
        'marketing': true,
      },
    );
  });
}
