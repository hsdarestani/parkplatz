import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/booking/data/repositories.dart';
import 'package:freiraum_parking/features/parking/data/demo_parking_repository.dart';
import 'package:freiraum_parking/features/parking/data/providers.dart';

void main() {
  for (final mode in [
    AppMode.checking,
    AppMode.localBeta,
    AppMode.unavailable,
  ]) {
    test('repository providers stay usable in ${mode.name} mode', () {
      final container = ProviderContainer(
        overrides: [
          appModeProvider.overrideWith(
            (ref) => AppModeController.fixed(mode),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(parkingRepositoryProvider),
        isA<DemoParkingRepository>(),
      );
      expect(
        container.read(authRepositoryProvider),
        isA<LocalBetaAuthRepository>(),
      );
      expect(
        () => container.read(availabilityRepositoryProvider),
        returnsNormally,
      );
      expect(
        () => container.read(vehicleRepositoryProvider),
        returnsNormally,
      );
      expect(
        () => container.read(bookingRepositoryProvider),
        returnsNormally,
      );
    });
  }
}
