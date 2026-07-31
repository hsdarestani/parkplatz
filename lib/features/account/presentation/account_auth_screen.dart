import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../config/environment.dart';
import '../../../core/network/api_client.dart';
import '../../booking/presentation/booking_screens.dart';
import '../../parking/data/providers.dart';
import '../data/social_auth_repository.dart';
import 'social_auth_buttons.dart';

class AccountAuthScreen extends ConsumerStatefulWidget {
  const AccountAuthScreen({
    super.key,
    required this.register,
    this.returnTo,
  });

  final bool register;
  final String? returnTo;

  @override
  ConsumerState<AccountAuthScreen> createState() => _AccountAuthScreenState();
}

class _AccountAuthScreenState extends ConsumerState<AccountAuthScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  late final Future<SocialAuthAvailability> socialAvailability =
      Environment.socialAuthUiEnabled
          ? ref.read(socialAuthRepositoryProvider).availability()
          : Future.value(const SocialAuthAvailability.disabled());

  bool accepted = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BetaScaffold(
        title: widget.register ? 'Konto erstellen' : 'Anmelden',
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: T.surface,
                  borderRadius: BorderRadius.circular(T.radius),
                  border: Border.all(color: T.line),
                  boxShadow: T.shadowSmall,
                ),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.register
                            ? 'Willkommen bei\nFREIRAUM'
                            : 'Schön, dich\nwiederzusehen',
                        style: const TextStyle(
                          fontSize: 28,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (widget.register) ...[
                        TextField(
                          key: const Key('auth-name-field'),
                          controller: name,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        key: const Key('auth-email-field'),
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'E-Mail'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const Key('auth-password-field'),
                        controller: password,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) {
                          if (!busy) _submit();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Passwort (mindestens 8 Zeichen)',
                        ),
                      ),
                      if (widget.register)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: accepted,
                          onChanged: (value) =>
                              setState(() => accepted = value ?? false),
                          title: const Text(
                            'Ich akzeptiere die Nutzungsbedingungen.',
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          key: const Key('auth-error'),
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          key: const Key('email-auth-submit'),
                          onPressed: busy ? null : _submit,
                          child: Text(
                            busy
                                ? 'Bitte warten …'
                                : widget.register
                                    ? 'Registrieren'
                                    : 'Anmelden',
                          ),
                        ),
                      ),
                      // Store builds do not expose unfinished authentication
                      // providers. When both native/provider setups are complete,
                      // SOCIAL_AUTH_UI_ENABLED can make this section visible.
                      if (Environment.socialAuthUiEnabled)
                        FutureBuilder<SocialAuthAvailability>(
                          future: socialAvailability,
                          initialData:
                              const SocialAuthAvailability.disabled(),
                          builder: (context, snapshot) {
                            final availability = snapshot.data ??
                                const SocialAuthAvailability.disabled();
                            return SocialAuthButtons(
                              googleEnabled: availability.googleEnabled,
                              appleEnabled: availability.appleEnabled,
                              onGooglePressed: () =>
                                  _socialNotReady(SocialAuthProvider.google),
                              onApplePressed: () =>
                                  _socialNotReady(SocialAuthProvider.apple),
                            );
                          },
                        ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _switchMode,
                        child: Text(
                          widget.register
                              ? 'Bereits registriert? Anmelden'
                              : 'Noch kein Konto? Registrieren',
                        ),
                      ),
                      if (!widget.register)
                        TextButton.icon(
                          onPressed: () => context.go('/forgot-password'),
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('Passwort vergessen?'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  void _switchMode() {
    final path = widget.register ? '/login' : '/register';
    context.go(
      widget.returnTo == null
          ? path
          : '$path?returnTo=${Uri.encodeComponent(widget.returnTo!)}',
    );
  }

  void _socialNotReady(SocialAuthProvider provider) {
    final label = provider == SocialAuthProvider.google ? 'Google' : 'Apple';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Anmeldung mit $label ist derzeit nicht verfügbar.',
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (widget.register && !accepted) {
      setState(() => error = 'Bitte akzeptiere die Nutzungsbedingungen.');
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      final auth = ref.read(authRepositoryProvider);
      if (widget.register) {
        await auth.register(name.text, email.text, password.text);
      } else {
        await auth.login(email.text, password.text);
      }
      if (mounted) context.go(widget.returnTo ?? '/bookings');
    } catch (exception) {
      if (mounted) {
        setState(
          () => error = exception is ApiException || exception is FormatException
              ? exception.toString()
              : 'Anmeldung nicht möglich.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
