import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/booking/presentation/premium_parking_detail.dart';
import 'package:freiraum_parking/shared/models/models.dart';

void main() {
  testWidgets('parking detail hero stays readable on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const space = ParkingSpace(
      id: 'phone-space',
      title: 'Praxisstellplatz Bockenheim',
      district: 'Bockenheim',
      landmark: 'Leipziger Straße',
      lat: 50.12,
      lng: 8.64,
      hourlyPrice: 3.5,
      walkingMeters: 250,
      walkingMinutes: 4,
      available: true,
      instant: true,
      covered: true,
      ev: false,
      accessible: true,
      maxHeight: 2.1,
      maxWidth: 2.4,
      maxLength: 5.2,
      access: AccessType.tiefgarage,
      entranceSummary: 'Zufahrt über den Innenhof',
      hostType: 'Praxis',
      verified: true,
      rating: 4.8,
      reviewCount: 18,
      cancellationSummary: 'Kostenlos stornierbar bis zwei Stunden vorher.',
      availabilityStatus: 'available',
      visual: VisualType.practice,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(14),
            child: ParkingDetailHero(space: space, owner: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.text('Praxisstellplatz Bockenheim');
    expect(title, findsOneWidget);
    expect(find.text('Sofort reservierbar'), findsOneWidget);
    expect(find.text('Verifiziert'), findsOneWidget);
    expect(tester.getSize(title).width, greaterThan(250));
    expect(tester.getSize(title).height, lessThan(120));
    expect(tester.takeException(), isNull);
  });
}
