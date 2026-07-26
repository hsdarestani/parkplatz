import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/booking/data/repositories.dart';
import 'package:freiraum_parking/features/parking/data/providers.dart';
import 'package:freiraum_parking/features/search/data/demo_search_data.dart';
import 'package:freiraum_parking/features/search/presentation/search_controller.dart';
import 'package:freiraum_parking/features/search/presentation/search_sheet_v2.dart';
import 'package:intl/date_symbol_data_local.dart';

class _VehicleRepository implements VehicleRepository {
  @override
  Future<List<VehicleRecord>> all() async => const [];

  @override
  Future<void> delete(String id) async {}

  @override
  Future<VehicleRecord> save(VehicleRecord vehicle) async => vehicle;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  testWidgets('multi-day search completes destination vehicle and filter steps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var submitted = false;
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appModeProvider.overrideWith(
            (ref) => AppModeController.fixed(AppMode.localBeta),
          ),
          vehicleRepositoryProvider.overrideWithValue(_VehicleRepository()),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              home: Scaffold(
                body: SearchSheetV2(onSubmit: () => submitted = true),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zeitraum'), findsOneWidget);
    await tester.tap(find.text('3 Tage'));
    await tester.pump();
    expect(container.read(searchProvider).hours, 72);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Ziel'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final destination = demoDestinations.first;
    await tester.tap(find.text(destination.name));
    await tester.pump();
    expect(container.read(searchProvider).destination, destination);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Fahrzeug'), findsOneWidget);

    await tester.tap(find.text('Marke'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volkswagen').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Modell'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Golf').last);
    await tester.pumpAndSettle();

    final vehicle = container.read(searchProvider).vehicle;
    expect(vehicle, isNotNull);
    expect(vehicle!.name, 'Volkswagen Golf');
    expect(vehicle.hasPlate, isFalse);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Filter'), findsOneWidget);

    await tester.tap(find.text('Kostenlos'));
    await tester.pump();
    expect(container.read(searchProvider).filters, contains('free'));

    await tester.tap(find.text('Freie Stellplätze anzeigen'));
    await tester.pump();
    expect(submitted, isTrue);
    expect(container.read(searchProvider).valid, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search wizard keeps continue disabled until required data exists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appModeProvider.overrideWith(
            (ref) => AppModeController.fixed(AppMode.localBeta),
          ),
          vehicleRepositoryProvider.overrideWithValue(_VehicleRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SearchSheetV2(onSubmit: _noop)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Ziel'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Weiter'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
