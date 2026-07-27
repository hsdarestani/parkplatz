import 'package:flutter/material.dart';

import 'account_auth_screen.dart';

class LoginEntryScreen extends StatelessWidget {
  const LoginEntryScreen({super.key, this.returnTo});

  final String? returnTo;

  @override
  Widget build(BuildContext context) => AccountAuthScreen(
        register: false,
        returnTo: returnTo,
      );
}
