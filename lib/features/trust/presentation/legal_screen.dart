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
          tooltip: 'Schließen',
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
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: T.success),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Diese Informationen gelten für die aktuelle Version von FREIRAUM. Wesentliche Änderungen werden hier veröffentlicht.',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'privacy',
                        icon: Icon(Icons.privacy_tip_outlined),
                        label: Text('Datenschutz'),
                      ),
                      ButtonSegment(
                        value: 'terms',
                        icon: Icon(Icons.gavel_outlined),
                        label: Text('Bedingungen'),
                      ),
                      ButtonSegment(
                        value: 'imprint',
                        icon: Icon(Icons.business_outlined),
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
              'Direktzahlung und kostenlose Angebote',
              'Kostenpflichtige Buchungen werden direkt vom Fahrer an den Anbieter über PayPal, Revolut oder SEPA bezahlt. FREIRAUM nimmt, verwahrt oder überweist keine Kundengelder. Anbieter können Stellplätze auch kostenlos anbieten.',
            ),
            (
              'Buchungsbestätigung',
              'Jede Buchung wird erst nach Bestätigung durch den Anbieter freigeschaltet. Dies gilt auch für als sofort reservierbar oder kostenlos gekennzeichnete Stellplätze. Erst danach werden genaue Adresse, Zugangsinformationen und Parking Pass sichtbar.',
            ),
            (
              'Fotos und automatische Prüfung',
              'Anbieter dürfen ausschließlich eigene oder rechtmäßig nutzbare Fotos von Stellplätzen hochladen. Fotos können automatisiert auf Relevanz, Qualität, unzulässige Inhalte und erkennbare personenbezogene Informationen geprüft werden. Nicht freigegebene Fotos werden nicht öffentlich angezeigt.',
            ),
            (
              'Bewertungen und nutzergenerierte Inhalte',
              'Bewertungen sind nur nach einem bestätigten und zeitlich beendeten Aufenthalt möglich. Verboten sind insbesondere beleidigende, diskriminierende, bedrohende, sexuelle, gewaltverherrlichende, betrügerische, rechtswidrige, fremde personenbezogene oder sonstige unangemessene Inhalte sowie Spam und Manipulation. Nutzer können problematische Inhalte melden und andere Nutzer blockieren. FREIRAUM kann gemeldete Inhalte prüfen, ausblenden oder entfernen und Konten bei Missbrauch einschränken oder sperren.',
            ),
            (
              'Stornierung und Rückerstattung',
              'Bei einer stornierbaren, bereits bestätigten Direktzahlung führt der Anbieter die Rückerstattung außerhalb von FREIRAUM durch und dokumentiert die Erstattungsreferenz anschließend in der Plattform.',
            ),
            (
              'Pflichten der Nutzer',
              'Nutzer müssen richtige Angaben machen, nur berechtigte Stellplätze anbieten, Zahlungsinformationen sorgfältig prüfen und Stellplätze, Fahrzeuge sowie Zugangsdaten verantwortungsvoll verwenden. Missbrauch, Täuschung, Belästigung, Umgehung von Sicherheitsmaßnahmen und rechtswidrige Inhalte sind untersagt.',
            ),
            (
              'Verfügbarkeit und Weiterentwicklung',
              'FREIRAUM wird fortlaufend weiterentwickelt. Funktionen können aus technischen, rechtlichen oder sicherheitsbezogenen Gründen angepasst werden. Eine ununterbrochene Verfügbarkeit kann nicht zugesichert werden.',
            ),
            (
              'Free und optionale Zusatzfunktionen',
              'FREIRAUM Free umfasst die jeweils in der App ausgewiesenen grundlegenden Anbieterfunktionen. Etwaige kostenpflichtige Zusatzfunktionen werden nur nach ausdrücklicher Aktivierung angeboten; Preise und Leistungsumfang werden vor einem Kauf transparent angezeigt.',
            ),
            (
              'Kontakt',
              'A+ Solution GmbH\nE-Mail: app@aplus-solution.de\nTelefon: +49 69 21000418',
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
              'Telefon: +49 69 21000418\nMobil: +49 172 7779721\nE-Mail: app@aplus-solution.de\nWebsite: www.aplus-solution.de',
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
              'A+ Solution GmbH\nCarl-Sonnenschein Straße 57\nD-65936 Frankfurt am Main\nE-Mail: app@aplus-solution.de',
            ),
            (
              'Verarbeitete Daten',
              'Verarbeitet werden insbesondere Konto- und Kontaktdaten, Profilbilder, Fahrzeugdaten, Stellplatzinformationen, Standort-Pins, Buchungs- und Zeitdaten, Zahlungsreferenzen, freiwillig hochgeladene Belege und Stellplatzfotos, Bewertungen, Support- und Moderationsangaben sowie technisch notwendige Sicherheitsprotokolle.',
            ),
            (
              'Zwecke und Rechtsgrundlagen',
              'Die Verarbeitung erfolgt zur Registrierung, Vermittlung und Durchführung von Buchungen, zur Zahlungs- und Rückerstattungsdokumentation, zur Kommunikation, Qualitäts- und Inhaltsmoderation, Missbrauchsprävention und technischen Sicherheit. Rechtsgrundlagen sind insbesondere Art. 6 Abs. 1 lit. b, c und f DSGVO.',
            ),
            (
              'Standortdaten',
              'Der Gerätestandort wird nur nach Zustimmung verwendet, um Stellplätze in der Nähe anzuzeigen oder eine Route zu berechnen. Nutzer können FREIRAUM auch ohne Standortfreigabe verwenden und Adressen manuell suchen. Genaue Stellplatzadressen, Zugangscodes und Einfahrthinweise werden erst nach einer bestätigten Buchung für den berechtigten Fahrer angezeigt.',
            ),
            (
              'Bild- und Inhaltsprüfung',
              'Hochgeladene Stellplatzfotos können automatisiert analysiert werden, damit ein nutzbarer Stellplatz erkennbar ist und problematische Inhalte oder deutlich erkennbare personenbezogene Daten nicht veröffentlicht werden. Meldungen zu Bewertungen oder anderen nutzergenerierten Inhalten werden zur Moderation gespeichert und bearbeitet. Nutzerblockierungen werden dem jeweiligen Konto zugeordnet, damit blockierte Inhalte ausgeblendet werden können.',
            ),
            (
              'Direkte Zahlungsanbieter',
              'Bei PayPal-, Revolut- oder Bankzahlungen nutzen Nutzer Dienste Dritter. Für deren eigenständige Datenverarbeitung gelten die Datenschutzinformationen des jeweiligen Zahlungsanbieters oder Kreditinstituts.',
            ),
            (
              'Empfänger und Hosting',
              'Daten werden nur an technisch notwendige Dienstleister, Hosting-, E-Mail-, Karten-, Geocoding-, Routing- und Prüfungsanbieter sowie im erforderlichen Umfang an den jeweiligen Buchungspartner übermittelt. Eine Weitergabe an Werbetreibende oder ein Verkauf personenbezogener Daten findet nicht statt.',
            ),
            (
              'Speicherdauer und Löschung',
              'Daten werden nur so lange gespeichert, wie sie für Betrieb, Buchungsabwicklung, Moderation, Sicherheits- und Nachweiszwecke oder gesetzliche Aufbewahrungspflichten erforderlich sind. Das Konto kann in der App unter Sicherheit & Datenschutz gelöscht werden. Zusätzlich kann eine Löschung ohne App-Zugriff über https://parkplatz.smarbiz.sbs/delete-account angefordert werden. Gesetzlich erforderliche Nachweisdaten werden nur im notwendigen Umfang und ohne aktive Profildaten aufbewahrt.',
            ),
            (
              'Rechte',
              'Betroffene Personen haben im gesetzlichen Rahmen insbesondere Rechte auf Auskunft, Berichtigung, Löschung, Einschränkung, Datenübertragbarkeit und Widerspruch nach Art. 15 bis 22 DSGVO sowie ein Beschwerderecht nach Art. 77 DSGVO.',
            ),
            (
              'Kontakt',
              'Datenschutz-, Moderations- und Löschanfragen können an app@aplus-solution.de gesendet werden.',
            ),
          ],
        ),
    };

class _LegalContent {
  const _LegalContent(this.title, this.blocks);

  final String title;
  final List<(String, String)> blocks;
}
