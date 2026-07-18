import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../data/trust_repository.dart';

class TrustCenterScreen extends ConsumerWidget {
  const TrustCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FreiraumScaffold(
        title: 'Vertrauen',
        subtitle: 'Prüfungen, Kontohilfe und rechtliche Informationen.',
        activePath: '/trust',
        child: FutureBuilder<TrustOverview>(
          future: ref.read(trustRepositoryProvider).overview(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [T.ink, T.inkSoft],
                            ),
                            borderRadius: BorderRadius.circular(T.radiusSpacious),
                            boxShadow: T.shadow,
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: T.mint,
                                size: 50,
                              ),
                              SizedBox(width: 18),
                              Expanded(
                                child: Text(
                                  'Sicher parken. Transparent vermieten.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _Metric('${data.verifiedSpaces}', 'verifiziert'),
                            _Metric(
                              '${data.pendingVerifications}',
                              'in Prüfung',
                            ),
                            _Metric('${data.openReports}', 'offen'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _Action(
                          icon: Icons.fact_check_outlined,
                          title: 'Stellplatzprüfung',
                          subtitle: 'Berechtigung für ein Angebot bestätigen.',
                          onTap: () => context.go('/trust/verification'),
                        ),
                        _Action(
                          icon: Icons.support_agent_outlined,
                          title: 'Kontohilfe',
                          subtitle: 'Anfrage zu Buchung oder Stellplatz senden.',
                          onTap: () => context.go('/trust/support'),
                        ),
                        _Action(
                          icon: Icons.gavel_outlined,
                          title: 'Rechtliches',
                          subtitle: 'Datenschutz, Bedingungen und Impressum.',
                          onTap: () => context.go('/legal/privacy'),
                        ),
                        if (data.isAdmin)
                          _Action(
                            icon: Icons.admin_panel_settings_outlined,
                            title: 'Moderation',
                            subtitle: 'Offene Fälle bearbeiten.',
                            onTap: () => context.go('/admin/trust'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        width: 200,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            Text(label, style: const TextStyle(color: T.muted)),
          ],
        ),
      );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Icon(icon, color: T.success),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}
