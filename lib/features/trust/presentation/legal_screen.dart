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
      subtitle: 'Rechtliche Informationen für FREIRAUM Public Beta.',
      activePath: '/trust',
      actions: [
        IconButton(
          onPressed: () => context.go('/'),
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
                      color: T.mintSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: T.mint),
                    ),
                    child: const Text(
                      'FREIRAUM befindet sich in einer öffentlichen Beta. Diese Informationen gelten für den aktuellen Funktionsumfang; wesentliche Änderungen werden an dieser Stelle veröffentlicht.',
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
              'FREIRAUM wird von der A+ Solution GmbH betrieben und vermittelt die technische Kontaktaufnahme und Buchungsabwicklung zwischen Parkplatzanbietern und Fahrern. FREIRAUM ist nicht Eigentümer oder Betreiber der angebotenen Stellplätze.',
            ),
            (
              'Direktzahlung',
              'Zahlungen erfolgen direkt vom Fahrer an den Anbieter über PayPal, Revolut oder SEPA. FREIRAUM nimmt, verwahrt oder überweist dabei keine Kundengelder. Zahlungsreferenzen und optional hochgeladene Belege dienen der Dokumentation und Prüfung.',
            ),
            (
              'Buchungsbestätigung',
              'Eine Buchung wird erst bestätigt, wenn der Anbieter den Zahlungseingang innerhalb der angezeigten Frist bestätigt. Erst danach werden die genaue Adresse, Zugangsinformationen und der Parking Pass freigeschaltet.',
            ),
            (
              'Stornierung und Rückerstattung',
              'Bei einer stornierbaren, bereits bestätigten Direktzahlung führt der Anbieter die Rückerstattung außerhalb von FREIRAUM durch und dokumentiert die Erstattungsreferenz anschließend in der Plattform.',
            ),
            (
              'Pflichten der Nutzer',
              'Nutzer müssen richtige Angaben machen, nur berechtigte Stellplätze anbieten, Zahlungsinformationen sorgfältig prüfen und Stellplätze, Fahrzeuge sowie Zugangsdaten verantwortungsvoll verwenden. Missbrauch, Täuschung und rechtswidrige Inhalte sind untersagt.',
            ),
            (
              'Beta-Betrieb und Verfügbarkeit',
              'FREIRAUM wird als Public Beta bereitgestellt. Funktionen können erweitert oder angepasst werden. Für planbare Wartung, technische Störungen oder Ausfälle kann keine ununterbrochene Verfügbarkeit zugesichert werden.',
            ),
            (
              'Free und Pro',
              'Der aktuelle Free-Plan umfasst die grundlegenden Anbieterfunktionen. Pro-Funktionen können während der Beta auf Anfrage freigeschaltet werden. Kostenpflichtige Preise werden vor einer späteren Aktivierung transparent angezeigt und nicht rückwirkend berechnet.',
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
              'Geschäftsführer: Ashkan Asadian Ghahferokhi',
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
              'A+ Solution GmbH, vertreten durch den Geschäftsführer Ashkan Asadian Ghahferokhi.',
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
              'Verarbeitet werden insbesondere Konto- und Kontaktdaten, Fahrzeugdaten, Stellplatzinformationen, Buchungs- und Zeitdaten, Zahlungsreferenzen, freiwillig hochgeladene Zahlungsbelege, Support- und Prüfungsangaben sowie technisch notwendige Sicherheitsprotokolle.',
            ),
            (
              'Zwecke und Rechtsgrundlagen',
              'Die Verarbeitung erfolgt zur Registrierung, Vermittlung und Durchführung von Buchungen, zur Zahlungs- und Rückerstattungsdokumentation, zur Kommunikation, zur Missbrauchsprävention und zur technischen Sicherheit. Rechtsgrundlagen sind insbesondere Art. 6 Abs. 1 lit. b, c und f DSGVO; optionale Marketingnachrichten werden nur mit entsprechender Einwilligung versendet.',
            ),
            (
              'Geschützte Standortdaten',
              'Genaue Stellplatzadressen, Zugangscodes und Einfahrthinweise werden erst nach einer bestätigten Buchung für den berechtigten Fahrer angezeigt.',
            ),
            (
              'Direkte Zahlungsanbieter',
              'Bei PayPal-, Revolut- oder Bankzahlungen verlassen Nutzer FREIRAUM beziehungsweise nutzen Dienste Dritter. Für deren eigenständige Datenverarbeitung gelten die Datenschutzinformationen des jeweiligen Zahlungsanbieters oder Kreditinstituts.',
            ),
            (
              'Empfänger und Hosting',
              'Daten werden nur an technisch notwendige Dienstleister, Hosting- und E-Mail-Anbieter sowie im erforderlichen Umfang an den jeweiligen Buchungspartner übermittelt. Eine Weitergabe an Werbetreibende oder ein Verkauf personenbezogener Daten findet nicht statt.',
            ),
            (
              'Speicherdauer',
              'Daten werden nur so lange gespeichert, wie sie für den Betrieb, die Buchungsabwicklung, Sicherheits- und Nachweiszwecke oder gesetzliche Aufbewahrungspflichten erforderlich sind. Kontodaten können über die Kontofunktionen zur Löschung angefordert werden, soweit keine gesetzlichen Gründe entgegenstehen.',
            ),
            (
              'Rechte',
              'Betroffene Personen haben im gesetzlichen Rahmen insbesondere Rechte auf Auskunft, Berichtigung, Löschung, Einschränkung, Datenübertragbarkeit und Widerspruch nach Art. 15 bis 22 DSGVO. Außerdem besteht ein Beschwerderecht bei einer Datenschutzaufsichtsbehörde gemäß Art. 77 DSGVO.',
            ),
            (
              'Kontakt',
              'Datenschutzanfragen können an info@aplus-solution.de gesendet werden.',
            ),
          ],
        ),
    };

class _LegalContent {
  const _LegalContent(this.title, this.blocks);

  final String title;
  final List<(String, String)> blocks;
}
