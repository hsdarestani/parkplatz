import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../data/account_controls_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final email = TextEditingController();
  bool busy = false;
  bool sent = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Passwort zurücksetzen',
        subtitle: 'Wir senden dir einen zeitlich begrenzten Link.',
        activePath: '/profile',
        actions: [
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Anmelden'),
          ),
        ],
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock_reset, size: 54),
                      const SizedBox(height: 16),
                      Text(
                        sent
                            ? 'E-Mail prüfen'
                            : 'Zugang zu deinem Konto wiederherstellen',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (sent)
                        const Text(
                          'Falls ein aktives Konto existiert, wurde ein Reset-Link gesendet.',
                        )
                      else ...[
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'E-Mail'),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 10),
                          Text(error!, style: const TextStyle(color: Colors.red)),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: busy ? null : _submit,
                          icon: const Icon(Icons.mail_outline),
                          label: Text(busy ? 'Wird gesendet …' : 'Reset-Link senden'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> _submit() async {
    final value = email.text.trim();
    if (!value.contains('@')) {
      setState(() => error = 'Bitte gib eine gültige E-Mail-Adresse ein.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(accountControlsRepositoryProvider)
          .requestPasswordReset(value);
      if (mounted) setState(() => sent = true);
    } catch (exception) {
      if (mounted) {
        setState(
          () => error = exception is ApiException
              ? exception.toString()
              : 'Die Anfrage konnte nicht gesendet werden.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Neues Passwort',
        subtitle: 'Wähle ein neues Passwort mit mindestens 8 Zeichen.',
        activePath: '/profile',
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Neues Passwort'),
                      ),
                      TextField(
                        controller: confirmation,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Passwort wiederholen'),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: busy ? null : _submit,
                        icon: const Icon(Icons.check),
                        label: Text(busy ? 'Wird gespeichert …' : 'Passwort speichern'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> _submit() async {
    if (widget.token.isEmpty) {
      setState(() => error = 'Der Reset-Link ist unvollständig.');
      return;
    }
    if (password.text.length < 8 || password.text != confirmation.text) {
      setState(() => error = 'Die Passwörter müssen übereinstimmen und mindestens 8 Zeichen haben.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(accountControlsRepositoryProvider).resetPassword(
            widget.token,
            password.text,
          );
      if (mounted) context.go('/login?password=reset');
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
