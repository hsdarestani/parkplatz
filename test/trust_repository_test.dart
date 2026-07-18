import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/trust/data/trust_repository.dart';

void main() {
  test('overview parses counters and role', () {
    final value = TrustOverview.fromJson({
      'pending_verifications': 2,
      'open_reports': 1,
      'verified_spaces': 3,
      'is_admin': true,
      'support_email': 'team@example.com',
    });

    expect(value.pendingVerifications, 2);
    expect(value.openReports, 1);
    expect(value.verifiedSpaces, 3);
    expect(value.isAdmin, isTrue);
  });
}
