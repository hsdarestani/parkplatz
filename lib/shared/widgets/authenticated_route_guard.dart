import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/parking/data/providers.dart';

class AuthenticatedRouteGuard extends ConsumerStatefulWidget {
  const AuthenticatedRouteGuard({
    super.key,
    required this.returnTo,
    required this.child,
  });

  final String returnTo;
  final Widget child;

  @override
  ConsumerState<AuthenticatedRouteGuard> createState() =>
      _AuthenticatedRouteGuardState();
}

class _AuthenticatedRouteGuardState
    extends ConsumerState<AuthenticatedRouteGuard> {
  late Future<bool> authentication;

  @override
  void initState() {
    super.initState();
    authentication = _restore();
  }

  Future<bool> _restore() async {
    final auth = ref.read(authRepositoryProvider);
    return auth.authenticated || await auth.restore();
  }

  void _retry() => setState(() => authentication = _restore());

  Future<void> _signInAgain() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      // Local tokens are cleared in the repository's finally block even when
      // the API cannot be reached. The sign-in route must still open.
    }
    if (mounted) {
      context.go(
        '/login?returnTo=${Uri.encodeComponent(widget.returnTo)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: authentication,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.data == true) return widget.child;

          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 52),
                      const SizedBox(height: 14),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Erneut versuchen'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_clock_outlined, size: 52),
                    const SizedBox(height: 14),
                    const Text(
                      'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _signInAgain,
                      icon: const Icon(Icons.login),
                      label: const Text('Erneut anmelden'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}
