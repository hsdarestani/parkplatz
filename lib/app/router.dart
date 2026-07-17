import 'package:go_router/go_router.dart';

import '../features/booking/presentation/booking_screens.dart';
import '../features/discovery/presentation/discovery_screen.dart';
import '../features/launch/launch_screen.dart';

GoRouter createRouter() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (c, s) => const LaunchScreen()),
        GoRoute(path: '/discover', builder: (c, s) => const DiscoveryScreen()),
        GoRoute(
          path: '/search',
          builder: (c, s) => const DiscoveryScreen(results: true),
        ),
        GoRoute(
          path: '/parking/:id',
          builder: (c, s) =>
              ParkingDetailScreen(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/login',
          builder: (c, s) => AuthScreen(
            register: false,
            returnTo: s.uri.queryParameters['returnTo'],
          ),
        ),
        GoRoute(
          path: '/register',
          builder: (c, s) => AuthScreen(
            register: true,
            returnTo: s.uri.queryParameters['returnTo'],
          ),
        ),
        GoRoute(
          path: '/checkout/:id',
          builder: (c, s) => CheckoutScreen(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/booking/:id/confirmed',
          builder: (c, s) => ConfirmationScreen(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/bookings',
          builder: (c, s) => const BookingsScreen(),
        ),
        GoRoute(
          path: '/bookings/:id/pass',
          builder: (c, s) => ParkingPassScreen(id: s.pathParameters['id']!),
        ),
      ],
    );
