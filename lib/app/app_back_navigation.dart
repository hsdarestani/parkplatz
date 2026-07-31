import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Keeps Android's system back action useful even when a destination was opened
/// with `go()`, which intentionally replaces the router history.
class AppBackNavigationGuard extends StatelessWidget {
  const AppBackNavigationGuard({
    super.key,
    required this.currentPath,
    required this.child,
  });

  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final fallback = backFallbackForPath(currentPath);
    final routerCanPop = router.canPop();

    return PopScope<Object?>(
      // At a real in-app root Android may close the app. Everywhere else we
      // intercept the pop and navigate to the logical parent route.
      canPop: routerCanPop || fallback == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || router.canPop()) return;
        final target = backFallbackForPath(currentPath);
        if (target != null && target != currentPath) router.go(target);
      },
      child: child,
    );
  }
}

/// Returns the logical parent for top-level routes that have no Navigator stack.
/// A `null` result marks a real app root where Android may exit normally.
String? backFallbackForPath(String path) {
  if (path == '/' || path == '/discover' || path == '/age-check') return null;

  final segments = Uri(path: path).pathSegments;

  if (segments.length >= 2 && segments.first == 'checkout') {
    return '/parking/${segments[1]}';
  }
  if (segments.length >= 2 && segments.first == 'parking') {
    return '/discover';
  }
  if (segments.isNotEmpty && segments.first == 'booking') {
    return '/bookings';
  }
  if (segments.length >= 2 && segments.first == 'bookings') {
    return '/bookings';
  }
  if (path == '/bookings') return '/discover';

  if (path == '/host') return '/discover';
  if (segments.isNotEmpty && segments.first == 'host') return '/host';

  if (path == '/profile') return '/discover';
  if (path == '/vehicles' ||
      path == '/favorites' ||
      path.startsWith('/account/') ||
      path.startsWith('/trust') ||
      path.startsWith('/legal/') ||
      path.startsWith('/admin/')) {
    return '/profile';
  }

  if (path == '/search' ||
      path == '/login' ||
      path == '/register' ||
      path == '/forgot-password' ||
      path == '/reset-password' ||
      path == '/onboarding' ||
      path == '/delete-account') {
    return '/discover';
  }

  if (path == '/payment-return') return '/bookings';

  return '/discover';
}
