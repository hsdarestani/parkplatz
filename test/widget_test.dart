import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/booking/data/repositories.dart';
import 'package:freiraum_parking/features/discovery/presentation/discovery_screen.dart';
import 'package:freiraum_parking/features/discovery/presentation/map_canvas.dart';
import 'package:freiraum_parking/features/parking/data/demo_parking_repository.dart';
import 'package:freiraum_parking/features/parking/data/providers.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget buildTestApp() {
  return ProviderScope(
    overrides: [
      appModeProvider.overrideWith(
        (ref) => AppModeController.fixed(AppMode.localBeta),
      ),
      parkingSpacesProvider.overrideWith(
        (ref) => Future.value(DemoParkingRepository.spaces),
      ),
    ],
    child: const MaterialApp(home: DiscoveryScreen()),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  testWidgets(
    'mobile discovery opens search with destination and vehicle controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Wohin möchtest du?'), findsOneWidget);
      expect(find.textContaining('passende Stellplätze'), findsWidgets);

      await tester.tap(find.text('Wohin möchtest du?').first);
      await tester.pumpAndSettle();

      expect(find.text('Ankunft vorbereiten'), findsOneWidget);
      expect(find.text('Ziel'), findsOneWidget);
      await tester.tap(find.text('Messe Frankfurt').first);
      await tester.pump();

      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('Fahrzeug'), findsOneWidget);
      expect(find.text('VW Golf'), findsOneWidget);
      expect(find.text('Stellplätze anzeigen'), findsOneWidget);
    },
  );

  testWidgets(
    'desktop layout shows side panel map and non-overlapping navigation rail',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(FreiraumMap), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
      expect(find.text('FREIRAUM'), findsOneWidget);
      expect(find.textContaining('Demo-Daten'), findsWidgets);
      expect(find.byType(DraggableScrollableSheet), findsNothing);

      final railLogoRect = tester.getRect(find.text('F'));
      final brandRect = tester.getRect(find.text('FREIRAUM'));
      final mapRect = tester.getRect(find.byType(FreiraumMap));

      expect(railLogoRect.center.dx, lessThan(brandRect.center.dx));
      expect(brandRect.right, lessThan(mapRect.right));
      expect(mapRect.width, greaterThan(700));
    },
  );
}
