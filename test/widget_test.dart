import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/config/design_tokens.dart';
import 'package:freiraum_parking/features/booking/data/repositories.dart';
import 'package:freiraum_parking/features/discovery/presentation/discovery_screen_v2.dart';
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
    child: const MaterialApp(home: DiscoveryScreenV2()),
  );
}

Future<void> disposeTestApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

class _DesktopLayoutContract extends StatelessWidget {
  const _DesktopLayoutContract();

  static const railKey = Key('desktop-rail');
  static const panelKey = Key('desktop-panel');
  static const mapKey = Key('desktop-map');
  static const railWidth = 76.0;

  @override
  Widget build(BuildContext context) {
    return const Material(
      child: Row(
        children: [
          SizedBox(key: railKey, width: railWidth),
          SizedBox(key: panelKey, width: T.desktopPanel),
          Expanded(child: SizedBox(key: mapKey)),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  testWidgets(
    'mobile discovery opens the guided multi-day timing step',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Wann und wohin?'), findsOneWidget);
      await tester.tap(find.text('Wann und wohin?'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Zeitraum'), findsOneWidget);
      expect(find.text('Einfahrt'), findsOneWidget);
      expect(find.text('Ausfahrt'), findsOneWidget);
      expect(find.text('3 Tage'), findsOneWidget);
      expect(find.text('Weiter'), findsOneWidget);

      await disposeTestApp(tester);
    },
  );

  testWidgets(
    'desktop layout contract reserves separate rail panel and map regions',
    (tester) async {
      const surface = Size(1440, 900);
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: _DesktopLayoutContract())),
      );
      await tester.pump();

      final railRect = tester.getRect(find.byKey(_DesktopLayoutContract.railKey));
      final panelRect = tester.getRect(find.byKey(_DesktopLayoutContract.panelKey));
      final mapRect = tester.getRect(find.byKey(_DesktopLayoutContract.mapKey));

      expect(railRect.width, _DesktopLayoutContract.railWidth);
      expect(panelRect.width, T.desktopPanel);
      expect(railRect.right, panelRect.left);
      expect(panelRect.right, mapRect.left);
      expect(mapRect.right, surface.width);
      expect(
        mapRect.width,
        surface.width - _DesktopLayoutContract.railWidth - T.desktopPanel,
      );
    },
  );
}
