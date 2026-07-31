import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/brand_config.dart';
import '../../../config/design_tokens.dart';
import 'onboarding_screen.dart';

const ageConfirmedKey = 'freiraum_age_18_confirmed_v1';

class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({super.key});

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  bool underAge = false;
  bool busy = false;

  Future<void> _confirmAdult() async {
    if (busy) return;
    setState(() => busy = true);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(ageConfirmedKey, true);
    final completed = preferences.getBool(onboardingCompletedKey) == true;
    if (mounted) context.go(completed ? '/discover' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: true,
        child: Scaffold(
          backgroundColor: T.porcelain,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: T.surface,
                      borderRadius: BorderRadius.circular(T.radiusSpacious),
                      border: Border.all(color: T.line),
                      boxShadow: T.shadowSmall,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: T.mintSoft,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.verified_user_outlined,
                            color: T.success,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          BrandConfig.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          underAge
                              ? 'FREIRAUM ist ab 18 Jahren verfügbar'
                              : 'Altersbestätigung',
                          style: const TextStyle(
                            fontSize: 28,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          underAge
                              ? 'FREIRAUM vermittelt reale Stellplätze, Buchungen und Zahlungen und ist daher nicht für Minderjährige bestimmt.'
                              : 'FREIRAUM richtet sich ausschließlich an volljährige Personen. Bitte wähle deine Altersgruppe.',
                          style: const TextStyle(
                            color: T.muted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!underAge) ...[
                          SizedBox(
                            height: 52,
                            child: FilledButton.icon(
                              key: const Key('age-gate-adult'),
                              onPressed: busy ? null : _confirmAdult,
                              icon: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: const Text('18 Jahre oder älter'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              key: const Key('age-gate-minor'),
                              onPressed: () => setState(() => underAge = true),
                              child: const Text('Unter 18 Jahre'),
                            ),
                          ),
                        ] else ...[
                          const ContainerMessage(),
                        ],
                        const SizedBox(height: 18),
                        TextButton(
                          onPressed: () => context.go('/legal/privacy'),
                          child: const Text('Datenschutz'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class ContainerMessage extends StatelessWidget {
  const ContainerMessage({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.porcelainDeep,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: T.ink),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Eine Nutzung der App ist vor Vollendung des 18. Lebensjahres nicht möglich.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
