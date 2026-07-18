import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../booking/presentation/booking_screens.dart';

class LoginEntryScreen extends StatelessWidget {
  const LoginEntryScreen({super.key, this.returnTo});

  final String? returnTo;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          AuthScreen(register: false, returnTo: returnTo),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: TextButton.icon(
                onPressed: () => context.go('/forgot-password'),
                icon: const Icon(Icons.lock_reset),
                label: const Text('Passwort vergessen?'),
              ),
            ),
          ),
        ],
      );
}
