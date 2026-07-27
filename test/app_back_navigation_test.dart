import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/app/app_back_navigation.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('logical parent routes cover replaced navigation history', () {
    expect(backFallbackForPath('/'), isNull);
    expect(backFallbackForPath('/discover'), isNull);
    expect(backFallbackForPath('/parking/space-1'), '/discover');
    expect(backFallbackForPath('/checkout/space-1'), '/parking/space-1');
    expect(backFallbackForPath('/booking/booking-1/confirmed'), '/bookings');
    expect(backFallbackForPath('/bookings/booking-1/pass'), '/bookings');
    expect(backFallbackForPath('/host/new'), '/host');
    expect(backFallbackForPath('/host/space-1/manage'), '/host');
    expect(backFallbackForPath('/vehicles'), '/profile');
    expect(backFallbackForPath('/account/security'), '/profile');
    expect(backFallbackForPath('/profile'), '/discover');
    expect(backFallbackForPath('/login'), '/discover');
  });

  testWidgets('system back returns a replaced top-level route to discover',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        ShellRoute(
          builder: (_, state, child) => AppBackNavigationGuard(
            currentPath: state.uri.path,
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/discover',
              builder: (_, __) => const Scaffold(body: Text('discover')),
            ),
            GoRoute(
              path: '/profile',
              builder: (_, __) => const Scaffold(body: Text('profile')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('profile'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('discover'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/discover');
  });
}
