import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';

class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.googleEnabled,
    required this.appleEnabled,
    this.onGooglePressed,
    this.onApplePressed,
  });

  final bool googleEnabled;
  final bool appleEnabled;
  final VoidCallback? onGooglePressed;
  final VoidCallback? onApplePressed;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _OrDivider(),
          const SizedBox(height: 14),
          _SocialButton(
            key: const Key('google-sign-in-button'),
            enabled: googleEnabled,
            onPressed: onGooglePressed,
            icon: const _GoogleMark(),
            label: 'Mit Google fortfahren',
          ),
          const SizedBox(height: 10),
          _SocialButton(
            key: const Key('apple-sign-in-button'),
            enabled: appleEnabled,
            onPressed: onApplePressed,
            icon: const Icon(Icons.apple, size: 23),
            label: 'Mit Apple fortfahren',
          ),
          if (!googleEnabled || !appleEnabled) ...[
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_clock_outlined, size: 16, color: T.muted),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Bald verfügbar – sichere Einrichtung läuft.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: T.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final bool enabled;
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 50,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: T.ink,
            disabledForegroundColor: T.muted,
            side: BorderSide(color: enabled ? T.ink : T.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(alignment: Alignment.centerLeft, child: icon),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (!enabled)
                const Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.lock_outline, size: 17),
                ),
            ],
          ),
        ),
      );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'oder',
              style: TextStyle(
                color: T.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Divider()),
        ],
      );
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: T.line),
        ),
        child: const Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}
