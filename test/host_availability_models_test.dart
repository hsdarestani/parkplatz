import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/host/data/host_availability_models.dart';

void main() {
  test('availability rule parses API times and serializes override price', () {
    final rule = HostAvailabilityRule.fromJson({
      'weekday': 2,
      'active': true,
      'start_time': '08:00:00',
      'end_time': '18:00:00',
      'price_override_cents': 450,
    });

    expect(rule.startTime, '08:00');
    expect(rule.endTime, '18:00');
    expect(rule.priceOverrideCents, 450);
    expect(rule.toApi(), {
      'weekday': 2,
      'active': true,
      'start_time': '08:00:00',
      'end_time': '18:00:00',
      'price_override_cents': 450,
    });
  });

  test('copyWith can clear a dynamic price', () {
    const rule = HostAvailabilityRule(
      weekday: 1,
      active: true,
      startTime: '08:00',
      endTime: '18:00',
      priceOverrideCents: 500,
    );

    expect(rule.copyWith(clearPrice: true).priceOverrideCents, isNull);
  });
}
