import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/config/design_tokens.dart';
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
      const screenSize = Size(1440, 900);
      const railWidth = 76.0;

      await tester.binding.setSurfaceSize(screenSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.byType(FreiraumMap), findsOneWidget);
      expect(find.textContaining('Demo-Daten'), findsWidgets);
      expect(
        find.text('Tiefgarage am Europagarten'),
        findsAtLeastNWidgets(1),
      );

      final mapRect = tester.getRect(find.byType(FreiraumMap));
      expect(mapRect.left, closeTo(railWidth + T.desktopPanel, 0.01));
      expect(mapRect.right, closeTo(screenSize.width, 0.01));
      expect(mapRect.top, closeTo(0, 0.01));
      expect(mapRect.bottom, closeTo(screenSize.height, 0.01));
    },
  );
}
