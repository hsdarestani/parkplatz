import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/discovery/presentation/discovery_screen.dart';

Widget buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: DiscoveryScreen(),
    ),
  );
}

void main() {
  testWidgets('responsive smoke discovery to search', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildTestApp());
    await tester.pump();

    expect(find.text('Wohin möchtest du?'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Suche öffnen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ankunft vorbereiten'), findsOneWidget);

    await tester.tap(find.text('Messe Frankfurt').first);
    await tester.pump();

    expect(find.text('VW Golf'), findsOneWidget);
    expect(find.text('Stellplätze anzeigen'), findsOneWidget);
  });

  testWidgets('desktop layout shows side panel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildTestApp());
    await tester.pump();

    expect(find.text('FREIRAUM'), findsOneWidget);
    expect(find.text('Ankommen, ohne zu suchen.'), findsOneWidget);
    expect(find.textContaining('Demo-Daten'), findsWidgets);
  });
}
