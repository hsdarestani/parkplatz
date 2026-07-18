import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../features/parking/data/providers.dart';

class AuthenticatedErrorState extends ConsumerWidget {
  const AuthenticatedErrorState({
    super.key,
    required this.error,
    required this.onRetry,
    required this.returnTo,
    this.onSignIn,
  });

  final Object? error;
  final VoidCallback onRetry;
  final String returnTo;
  final Future<void> Function()? onSignIn;

  bool get _sessionExpired => error is ApiUnauthorizedException;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = _sessionExpired
        ? 'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.'
        : error.toString();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _sessionExpired ? Icons.lock_clock_outlined : Icons.cloud_off_outlined,
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                if (!_sessionExpired) {
                  onRetry();
                  return;
                }

                if (onSignIn != null) {
                  await onSignIn!();
                  return;
                }

                try {
                  await ref.read(authRepositoryProvider).logout();
                } catch (_) {
                  // Tokens are cleared by the repository even if logout cannot
                  // reach the API. Navigation to sign-in must still continue.
                }
                if (context.mounted) {
                  context.go(
                    '/login?returnTo=${Uri.encodeComponent(returnTo)}',
                  );
                }
              },
              icon: Icon(_sessionExpired ? Icons.login : Icons.refresh),
              label: Text(
                _sessionExpired ? 'Erneut anmelden' : 'Erneut versuchen',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
