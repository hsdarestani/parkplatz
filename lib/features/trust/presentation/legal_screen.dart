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
    final isImprint = section == 'imprint';
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
                  if (!isImprint) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: T.amberSoft,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: T.amber),
                      ),
                      child: const Text(
                        'Entwurf für das MVP. Datenschutz und Nutzungsbedingungen müssen vor dem öffentlichen Release rechtlich geprüft und finalisiert werden.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
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
                            SelectableText(block.$2),
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
              'FREIRAUM wird von der A+ Solution GmbH betrieben und vermittelt Stellplätze zwischen Anbietern und Fahrern. Die konkreten Rechte und Pflichten der Parteien werden in den finalen Nutzungsbedingungen geregelt.',
            ),
            (
              'Buchung und Stornierung',
              'Preise, Zeiträume, Zahlungsstatus und Stornierungsfolgen werden vor Abschluss transparent angezeigt.',
            ),
            (
              'Zulässige Nutzung',
              'Nutzer müssen richtige Angaben machen und Stellplätze sowie Zugangsinformationen verantwortungsvoll verwenden.',
            ),
            (
              'Kontakt',
              'A+ Solution GmbH\nE-Mail: info@aplus-solution.de\nTelefon: +49 69 21000418',
            ),
          ],
        ),
      'imprint' => const _LegalContent(
          'Impressum',
          [
            (
              'Angaben gemäß § 5 DDG',
              'A+ Solution GmbH\nCarl-Sonnenschein Straße 57\nD-65936 Frankfurt am Main\nDeutschland',
            ),
            (
              'Vertretungsberechtigt',
              'Geschäftsführer: Ashkan Asadian G.',
            ),
            (
              'Kontakt',
              'Telefon: +49 69 21000418\nMobil: +49 172 7779721\nE-Mail: info@aplus-solution.de\nWebsite: www.aplus-solution.de',
            ),
            (
              'Register und Umsatzsteuer',
              'Handelsregister: HRB 128570\nUmsatzsteuer-Identifikationsnummer gemäß § 27a UStG: DE296290089',
            ),
            (
              'Verantwortlich für den Inhalt',
              'A+ Solution GmbH, vertreten durch den Geschäftsführer Ashkan Asadian G.',
            ),
          ],
        ),
      _ => const _LegalContent(
          'Datenschutz',
          [
            (
              'Verantwortlicher',
              'A+ Solution GmbH\nCarl-Sonnenschein Straße 57\nD-65936 Frankfurt am Main\nE-Mail: info@aplus-solution.de',
            ),
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
              'Anfragen zu Auskunft, Berichtigung, Löschung oder Einschränkung der Verarbeitung können an info@aplus-solution.de gesendet werden.',
            ),
          ],
        ),
    };

class _LegalContent {
  const _LegalContent(this.title, this.blocks);

  final String title;
  final List<(String, String)> blocks;
}
