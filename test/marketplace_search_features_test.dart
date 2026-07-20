import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/search/data/demo_search_data.dart';
import 'package:freiraum_parking/features/search/data/vehicle_catalog.dart';
import 'package:freiraum_parking/features/search/presentation/search_controller.dart';
import 'package:freiraum_parking/shared/models/models.dart';

void main() {
  const space = ParkingSpace(
    id: 'space',
    title: 'Innenhof',
    district: 'Gallus',
    landmark: 'Messe',
    lat: 50.111,
    lng: 8.650,
    hourlyPrice: 0,
    walkingMeters: 999,
    walkingMinutes: 99,
    available: true,
    instant: true,
    covered: false,
    ev: false,
    accessible: true,
    maxHeight: 2.1,
    maxWidth: 2.5,
    maxLength: 5.2,
    access: AccessType.tor,
    entranceSummary: 'Tor links',
    hostType: 'Privat',
    verified: true,
    rating: 0,
    reviewCount: 0,
    cancellationSummary: 'Flexibel',
    availabilityStatus: 'available',
    visual: VisualType.courtyard,
  );

  test('distance is derived from the selected destination instead of mock data', () {
    const destination = Destination(
      'nearby',
      'Messe Frankfurt',
      'Westend',
      50.1115,
      8.6505,
    );

    expect(space.walkingMetersTo(destination), lessThan(200));
    expect(space.walkingMinutesTo(destination), lessThan(5));
    expect(space.walkingMinutesTo(destination), isNot(space.walkingMinutes));
  });

  test('free and indoor/outdoor labels are derived consistently', () {
    expect(space.free, isTrue);
    expect(space.indoor, isFalse);
    expect(space.outdoor, isTrue);
    expect(space.accessLabel(), contains('Innenhof'));
  });

  test('search controller supports manual multi-day duration', () {
    final controller = SearchController();
    final start = DateTime(2026, 7, 20, 14, 30);

    controller.start(start);
    controller.durationValue(const Duration(days: 3));

    expect(controller.state.start, start);
    expect(controller.state.end, start.add(const Duration(days: 3)));
    expect(controller.state.hours, 72);
    expect(controller.state.durationLabel(), contains('3 Tage'));
  });

  test('garage inside outside filters stay mutually exclusive', () {
    final controller = SearchController();

    controller.exclusiveAccessFilter('garage');
    expect(controller.state.filters, contains('garage'));

    controller.exclusiveAccessFilter('outdoor');
    expect(controller.state.filters, contains('outdoor'));
    expect(controller.state.filters, isNot(contains('garage')));
    expect(controller.state.filters, isNot(contains('indoor')));
  });

  test('simple vehicle classes remain available without an account vehicle', () {
    expect(demoVehicles.map((vehicle) => vehicle.name), contains('Kleinwagen'));
    expect(demoVehicles.map((vehicle) => vehicle.name), contains('SUV'));
    expect(demoVehicles.length, greaterThanOrEqualTo(5));
  });

  test('vehicle catalog provides brand then model without fake license plates', () {
    expect(vehicleBrands, containsAll(['Audi', 'BMW', 'Volkswagen']));

    final models = vehicleModelsFor('Volkswagen');
    expect(models.map((entry) => entry.model), containsAll(['Polo', 'Golf', 'Tiguan']));

    final golf = models.firstWhere((entry) => entry.model == 'Golf').toVehicle();
    expect(golf.name, 'Volkswagen Golf');
    expect(golf.hasPlate, isFalse);
    expect(golf.plate, isEmpty);
  });
}
