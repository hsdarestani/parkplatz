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

final parkingResultsProvider = Provider<AsyncValue<List<ParkingSpace>>>((ref) {
  final query = ref.watch(searchProvider);
  return ref
      .watch(parkingSpacesProvider)
      .whenData((spaces) => filterParkingSpaces(spaces, query));
});

final parkingSpaceProvider = FutureProvider.family<ParkingSpace?, String>((ref, id) {
  return ref.watch(parkingRepositoryProvider).byId(id);
});

final selectedParkingIdProvider = StateProvider<String?>((ref) => null);

final parkingResultsListProvider = Provider<List<ParkingSpace>>(
  (ref) => ref.watch(parkingResultsProvider).valueOrNull ?? const [],
);
