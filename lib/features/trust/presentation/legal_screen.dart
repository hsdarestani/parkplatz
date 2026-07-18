import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    final content = _content(section);
    return FreiraumScaffold(
      title: content.title,
      subtitle: 'Rechtliche Informationen für FREIRAUM.',
      activePath: '/trust',
      actions: [
        IconButton(
          onPressed: () => context.go('/trust'),
          icon: const Icon(Icons.close),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: T.amberSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: T.amber),
                    ),
                    child: const Text(
                      'Entwurf für das MVP. Vor dem öffentlichen Release muss der finale Text rechtlich geprüft und mit den vollständigen Unternehmensdaten ergänzt werden.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'privacy',
                        label: Text('Datenschutz'),
                      ),
                      ButtonSegment(
                        value: 'terms',
                        label: Text('Bedingungen'),
                      ),
                      ButtonSegment(
                        value: 'imprint',
                        label: Text('Impressum'),
                      ),
                    ],
                    selected: {section},
                    onSelectionChanged: (values) =>
                        context.go('/legal/${values.first}'),
                  ),
                  const SizedBox(height: 18),
                  ...content.blocks.map(
                    (block) => Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              block.$1,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(block.$2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

_LegalContent _content(String section) => switch (section) {
      'terms' => const _LegalContent(
          'Nutzungsbedingungen',
          [
            (
              'Plattformrolle',
              'FREIRAUM vermittelt Stellplätze zwischen Anbietern und Fahrern. Die konkreten Pflichten der Parteien werden in den finalen Bedingungen festgelegt.',
            ),
            (
              'Buchung und Stornierung',
              'Preise, Zeiträume, Zahlungsstatus und Stornierungsfolgen werden vor Abschluss transparent angezeigt.',
            ),
            (
              'Zulässige Nutzung',
              'Nutzer müssen richtige Angaben machen und Stellplätze sowie Zugangsinformationen verantwortungsvoll verwenden.',
            ),
          ],
        ),
      'imprint' => const _LegalContent(
          'Impressum',
          [
            (
              'Anbieter',
              'Unternehmensname, Rechtsform, vertretungsberechtigte Person und vollständige Anschrift ergänzen.',
            ),
            (
              'Kontakt',
              'E-Mail: support@freiraum.app\nTelefon und weitere Pflichtangaben vor Veröffentlichung ergänzen.',
            ),
            (
              'Register und Steuer',
              'Registergericht, Registernummer und Umsatzsteuer-ID ergänzen, sofern zutreffend.',
            ),
          ],
        ),
      _ => const _LegalContent(
          'Datenschutz',
          [
            (
              'Verarbeitete Daten',
              'Kontodaten, Fahrzeugdaten, Buchungen, Zahlungsreferenzen und technische Protokolle werden nur für den Betrieb der Plattform verarbeitet.',
            ),
            (
              'Geschützte Standortdaten',
              'Genaue Stellplatzadressen und Zugangsdaten werden erst nach einer bestätigten Buchung angezeigt.',
            ),
            (
              'Rechte und Kontakt',
              'Anfragen zu Auskunft, Berichtigung oder Löschung können an support@freiraum.app gesendet werden.',
            ),
          ],
        ),
    };

class _LegalContent {
  const _LegalContent(this.title, this.blocks);
  final String title;
  final List<(String, String)> blocks;
}
