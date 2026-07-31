import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/onboarding/presentation/age_gate_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('age gate offers neutral adult and minor choices', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AgeGateScreen()),
    );

    expect(find.text('Altersbestätigung'), findsOneWidget);
    expect(find.text('18 Jahre oder älter'), findsOneWidget);
    expect(find.text('Unter 18 Jahre'), findsOneWidget);
  });

  testWidgets('minor choice blocks access', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AgeGateScreen()),
    );

    await tester.tap(find.text('Unter 18 Jahre'));
    await tester.pump();

    expect(
      find.text('FREIRAUM ist ab 18 Jahren verfügbar'),
      findsOneWidget,
    );
    expect(find.text('18 Jahre oder älter'), findsNothing);
  });
}
