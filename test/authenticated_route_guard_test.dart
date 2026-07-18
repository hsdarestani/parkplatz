import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/booking/data/repositories.dart';
import 'package:freiraum_parking/features/parking/data/providers.dart';
import 'package:freiraum_parking/shared/widgets/authenticated_route_guard.dart';
import 'package:go_router/go_router.dart';

class _ExpiredAuthRepository implements AuthRepository {
  bool logoutCalled = false;

  @override
  bool get authenticated => false;

  @override
  AppUser? get currentUser => null;

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> register(String name, String email, String password) async {}

  @override
  Future<bool> restore() async => false;

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }
}

void main() {
  testWidgets('expired protected route opens sign in and preserves return path',
      (tester) async {
    final auth = _ExpiredAuthRepository();
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => const AuthenticatedRouteGuard(
            returnTo: '/profile',
            child: Scaffold(body: Text('Protected profile')),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => Scaffold(
            body: Text(
              'Login ${state.uri.queryParameters['returnTo']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Sitzung ist abgelaufen'), findsOneWidget);
    expect(find.text('Erneut anmelden'), findsOneWidget);

    await tester.tap(find.text('Erneut anmelden'));
    await tester.pumpAndSettle();

    expect(auth.logoutCalled, isTrue);
    expect(find.text('Login /profile'), findsOneWidget);
  });
}
