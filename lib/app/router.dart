import 'package:go_router/go_router.dart';

import '../features/account/presentation/profile_screen.dart';
import '../features/account/presentation/vehicles_screen.dart';
import '../features/booking/presentation/booking_screens.dart';
import '../features/discovery/presentation/discovery_screen.dart';
import '../features/host/presentation/host_dashboard_screen.dart';
import '../features/host/presentation/host_listing_wizard.dart';
import '../features/launch/launch_screen.dart';
import '../shared/widgets/authenticated_route_guard.dart';

AuthenticatedRouteGuard _protected(String path, Widget child) =>
    AuthenticatedRouteGuard(returnTo: path, child: child);

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
          builder: (context, state) {
            final path = '/checkout/${state.pathParameters['id']}';
            return _protected(
              path,
              CheckoutScreen(id: state.pathParameters['id']!),
            );
          },
        ),
        GoRoute(
          path: '/booking/:id/confirmed',
          builder: (context, state) {
            final path = '/booking/${state.pathParameters['id']}/confirmed';
            return _protected(
              path,
              ConfirmationScreen(id: state.pathParameters['id']!),
            );
          },
        ),
        GoRoute(
          path: '/bookings',
          builder: (context, state) =>
              _protected('/bookings', const BookingsScreen()),
        ),
        GoRoute(
          path: '/bookings/:id/pass',
          builder: (context, state) {
            final path = '/bookings/${state.pathParameters['id']}/pass';
            return _protected(
              path,
              ParkingPassScreen(id: state.pathParameters['id']!),
            );
          },
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              _protected('/profile', const ProfileScreen()),
        ),
        GoRoute(
          path: '/vehicles',
          builder: (context, state) =>
              _protected('/vehicles', const VehiclesScreen()),
        ),
        GoRoute(
          path: '/host',
          builder: (context, state) =>
              _protected('/host', const HostDashboardScreen()),
        ),
        GoRoute(
          path: '/host/new',
          builder: (context, state) =>
              _protected('/host/new', const HostListingWizardScreen()),
        ),
      ],
    );
