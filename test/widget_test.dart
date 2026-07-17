import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/app/app.dart';

Future<void> pumpPastLaunch(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump();
}

void main() {
  testWidgets('responsive smoke discovery to search', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: FreiraumApp()),
    );
    await pumpPastLaunch(tester);

    expect(find.text('Wohin möchtest du?'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Suche öffnen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Messe Frankfurt').first);
    await tester.pump();

    expect(find.text('VW Golf'), findsOneWidget);
    expect(find.text('Stellplätze anzeigen'), findsOneWidget);
  });

  testWidgets('desktop layout shows side panel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: FreiraumApp()),
    );
    await pumpPastLaunch(tester);

    expect(find.text('FREIRAUM'), findsWidgets);
    expect(find.text('Ankommen, ohne zu suchen.'), findsOneWidget);
  });
}
