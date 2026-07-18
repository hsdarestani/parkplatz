import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/booking/data/repositories.dart';
import 'package:freiraum_parking/features/host/data/host_repository.dart';
import 'package:freiraum_parking/features/parking/data/demo_parking_repository.dart';
import 'package:freiraum_parking/features/parking/data/providers.dart';
import 'package:freiraum_parking/features/payment/data/payment_aware_booking_repository.dart';
import 'package:freiraum_parking/features/search/data/demo_search_data.dart';
import 'package:freiraum_parking/shared/models/models.dart';

void main() {
  test('demo data is consistent and protects exact addresses', () async {
    final spaces = await DemoParkingRepository().all();
    expect(spaces, hasLength(12));
    for (final space in spaces) {
      expect(space.title, isNot(contains('Parking 1')));
      expect(space.approximate(), contains(space.district));
      expect(space.currency, 'EUR');
    }
  });

  test('parking compatibility logic works', () {
    final space = DemoParkingRepository.spaces.first;
    expect(space.fits(demoVehicles.first), isTrue);
    expect(space.fits(demoVehicles[2]), isFalse);
  });

  test('filters and sorting update results', () {
    final query = SearchQuery(
      destination: demoDestinations.first,
      start: DateTime(2026, 7, 17, 18),
      end: DateTime(2026, 7, 17, 22),
      vehicle: demoVehicles.first,
      filters: {'ev', 'covered', 'fit'},
      sort: 'Preis',
    );
    final results = filterParkingSpaces(
      DemoParkingRepository.spaces,
      query,
    );
    expect(
      results.every(
        (space) =>
            space.ev && space.covered && space.fits(demoVehicles.first),
      ),
      isTrue,
    );
    expect(results.first.hourlyPrice <= results.last.hourlyPrice, isTrue);
  });

  test('UUID parking IDs are preserved by repository lookup', () async {
    const uuid = '7cc92f53-f948-4c18-8c15-68220f915f11';
    expect(await DemoParkingRepository().byId(uuid), isNull);
  });

  test('booking idempotency keys are web safe and unique', () {
    final first = createBookingIdempotencyKey();
    final second = createBookingIdempotencyKey();

    expect(first, isNotEmpty);
    expect(second, isNotEmpty);
    expect(second, isNot(first));
    expect(first, matches(RegExp(r'^[a-z0-9]+-[a-z0-9]+$')));
  });

  test('API repositories are available during startup health check', () {
    final container = ProviderContainer(
      overrides: [
        appModeProvider.overrideWith(
          (ref) => AppModeController.fixed(AppMode.checking),
        ),
      ],
    );
    addTearDown(container.dispose);

    final repository = container.read(bookingRepositoryProvider);
    expect(repository, isA<PaymentAwareBookingRepository>());
    expect(
      (repository as PaymentAwareBookingRepository).delegate,
      isA<ApiBookingRepository>(),
    );
  });

  test('host listing API payload hides local-only fields', () {
    const space = HostSpaceRecord(
      id: 'local-id',
      title: 'Innenhof Sachsenhausen',
      district: 'Sachsenhausen',
      landmark: 'Schweizer Platz',
      latitude: 50.104,
      longitude: 8.689,
      exactAddress: 'Musterstraße 12',
      entranceInstructions: 'Durch das grüne Tor fahren.',
      hourlyPriceCents: 350,
      maxHeight: 2.1,
      maxWidth: 2.5,
      maxLength: 5.2,
      accessType: 'gate',
      covered: false,
      evCharging: false,
      accessible: true,
      instantBookable: true,
      verified: false,
      status: 'active',
    );

    expect(space.toApi(), isNot(contains('id')));
    expect(space.toApi(), isNot(contains('status')));
    expect(space.toApi()['exact_address'], 'Musterstraße 12');
  });
}
