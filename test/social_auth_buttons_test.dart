import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/account/presentation/social_auth_buttons.dart';

void main() {
  testWidgets('Google and Apple buttons are visible but disabled by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SocialAuthButtons(
            googleEnabled: false,
            appleEnabled: false,
          ),
        ),
      ),
    );

    final googleFinder = find.widgetWithText(
      OutlinedButton,
      'Mit Google fortfahren',
    );
    final appleFinder = find.widgetWithText(
      OutlinedButton,
      'Mit Apple fortfahren',
    );

    expect(googleFinder, findsOneWidget);
    expect(appleFinder, findsOneWidget);
    expect(find.textContaining('Bald verfügbar'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(googleFinder).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(appleFinder).onPressed, isNull);
  });
}
