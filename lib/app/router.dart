import 'package:go_router/go_router.dart';

import '../features/account/presentation/profile_screen.dart';
import '../features/account/presentation/vehicles_screen.dart';
import '../features/booking/presentation/booking_screens.dart';
import '../features/discovery/presentation/discovery_screen.dart';
import '../features/host/presentation/host_dashboard_screen.dart';
import '../features/host/presentation/host_listing_wizard.dart';
import '../features/launch/launch_screen.dart';

GoRouter createRouter() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LaunchScreen()),
        GoRoute(
          path: '/discover',
          builder: (context, state) => const DiscoveryScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const DiscoveryScreen(results: true),
        ),
        GoRoute(
          path: '/parking/:id',
          builder: (context, state) =>
              ParkingDetailScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => AuthScreen(
            register: false,
            returnTo: state.uri.queryParameters['returnTo'],
          ),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => AuthScreen(
            register: true,
            returnTo: state.uri.queryParameters['returnTo'],
          ),
        ),
        GoRoute(
          path: '/checkout/:id',
          builder: (context, state) =>
              CheckoutScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/booking/:id/confirmed',
          builder: (context, state) =>
              ConfirmationScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/bookings',
          builder: (context, state) => const BookingsScreen(),
        ),
        GoRoute(
          path: '/bookings/:id/pass',
          builder: (context, state) =>
              ParkingPassScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/vehicles',
          builder: (context, state) => const VehiclesScreen(),
        ),
        GoRoute(
          path: '/host',
          builder: (context, state) => const HostDashboardScreen(),
        ),
        GoRoute(
          path: '/host/new',
          builder: (context, state) => const HostListingWizardScreen(),
        ),
      ],
    );
