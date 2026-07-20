import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../booking/data/owner_aware_availability_repository.dart';
import '../../booking/data/repositories.dart';
import '../../payment/data/payment_aware_booking_repository.dart';
import '../../../shared/models/models.dart';
import '../../search/presentation/search_controller.dart';
import 'demo_parking_repository.dart';

T _forMode<T>(AppMode mode, T Function() api, T Function() local) {
  return switch (mode) {
    AppMode.checking || AppMode.api => api(),
    AppMode.localBeta => local(),
    AppMode.unavailable =>
      throw StateError('Datenquelle ist noch nicht verfügbar.'),
  };
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final mode = ref.watch(appModeProvider);
  return _forMode(
    mode,
    () => ApiAuthRepository(
      ref.watch(apiClientProvider),
      ref.watch(tokenStorageProvider),
    ),
    LocalBetaAuthRepository.new,
  );
});

final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  final mode = ref.watch(appModeProvider);
  return _forMode(
    mode,
    () => ApiParkingRepository(ref.watch(apiClientProvider)),
    DemoParkingRepository.new,
  );
});

final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  final mode = ref.watch(appModeProvider);
  return _forMode(
    mode,
    () => OwnerAwareApiAvailabilityRepository(
      ref.watch(apiClientProvider),
    ),
    LocalAvailabilityRepository.new,
  );
});

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  final mode = ref.watch(appModeProvider);
  return _forMode(
    mode,
    () => ApiVehicleRepository(ref.watch(apiClientProvider)),
    LocalVehicleRepository.new,
  );
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final mode = ref.watch(appModeProvider);
  return _forMode(
    mode,
    () {
      final api = ref.watch(apiClientProvider);
      return PaymentAwareBookingRepository(ApiBookingRepository(api), api);
    },
    LocalBetaBookingRepository.new,
  );
});

final parkingSpacesProvider = FutureProvider<List<ParkingSpace>>((ref) async {
  final repository = ref.watch(parkingRepositoryProvider);
  return repository.all();
});

final selectedParkingIdProvider = StateProvider<String?>((ref) => null);

final parkingResultsProvider = FutureProvider<List<ParkingSpace>>((ref) async {
  final query = ref.watch(searchProvider);
  final spaces = await ref.watch(parkingSpacesProvider.future);
  var results = filterParkingSpaces(spaces, query).where((space) {
    final filters = query.filters;
    final garageOk = !filters.contains('garage') ||
        space.access == AccessType.tiefgarage;
    final indoorOk = !filters.contains('indoor') || space.indoor;
    final outdoorOk = !filters.contains('outdoor') || space.outdoor;
    final freeOk = !filters.contains('free') || space.free;
    return garageOk && indoorOk && outdoorOk && freeOk;
  }).toList();

  if (query.valid) {
    final availability = ref.watch(availabilityRepositoryProvider);
    final checks = await Future.wait(
      results.map(
        (space) async => (
          space,
          await availability.check(space.id, query.start, query.end),
        ),
      ),
    );
    results = checks
        .where((entry) => entry.$2.available)
        .map((entry) => entry.$1)
        .toList();
  }

  if (query.sort == 'Preis') {
    results.sort((a, b) => a.hourlyPrice.compareTo(b.hourlyPrice));
  } else if (query.sort == 'Entfernung') {
    results.sort(
      (a, b) => a
          .walkingMetersTo(query.destination)
          .compareTo(b.walkingMetersTo(query.destination)),
    );
  }
  return results;
});

final parkingSpaceProvider = FutureProvider.family<ParkingSpace?, String>((ref, id) {
  return ref.watch(parkingRepositoryProvider).byId(id);
});

final parkingResultsListProvider = Provider<List<ParkingSpace>>((ref) {
  final values = ref.watch(parkingResultsProvider).valueOrNull ?? const [];
  final selected = ref.watch(selectedParkingIdProvider);
  if (selected == null || values.length < 2) return values;

  final selectedIndex = values.indexWhere((space) => space.id == selected);
  if (selectedIndex <= 0) return values;
  return [values[selectedIndex], ...values.take(selectedIndex), ...values.skip(selectedIndex + 1)];
});
