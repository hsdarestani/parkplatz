import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/design_tokens.dart';

class AccountDeletionPublicScreen extends StatelessWidget {
  const AccountDeletionPublicScreen({super.key});

  static const supportEmail = 'app@aplus-solution.de';

  Future<void> _requestDeletion(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {
        'subject': 'FREIRAUM – Konto löschen',
        'body': 'Hallo FREIRAUM Team,\n\nich möchte mein FREIRAUM Konto und die damit verbundenen personenbezogenen Daten löschen lassen.\n\nE-Mail-Adresse des Kontos: \n\nViele Grüße',
      },
    );
    if (!await launchUrl(uri)) {
      await Clipboard.setData(const ClipboardData(text: supportEmail));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'E-Mail-Adresse wurde kopiert. Bitte sende deine Löschanfrage an app@aplus-solution.de.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.canvas,
        appBar: AppBar(
          title: const Text('FREIRAUM – Konto löschen'),
          actions: [
            TextButton(
              onPressed: () => context.go('/legal/privacy'),
              child: const Text('Datenschutz'),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: T.surface,
                          borderRadius: BorderRadius.circular(T.radiusSpacious),
                          border: Border.all(color: T.line),
                          boxShadow: T.shadowSmall,
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 44,
                              color: T.success,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Löschung deines FREIRAUM Kontos anfordern',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'FREIRAUM wird von der A+ Solution GmbH betrieben. Du kannst die Löschung deines Kontos auch dann anfordern, wenn du keinen Zugriff mehr auf die App hast.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'So funktioniert es',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text('1. Sende die Anfrage von der E-Mail-Adresse deines FREIRAUM Kontos.'),
                              SizedBox(height: 8),
                              Text('2. Wir prüfen die Kontozuordnung und bestätigen die Anfrage bei Bedarf.'),
                              SizedBox(height: 8),
                              Text('3. Das Konto und die damit verbundenen personenbezogenen Daten werden gelöscht oder anonymisiert. Daten, die wir aufgrund gesetzlicher Pflichten aufbewahren müssen, werden nur im erforderlichen Umfang gespeichert.'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.email_outlined),
                          title: const Text(
                            supportEmail,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: const Text('Kontakt für Konto- und Datenschutzanfragen'),
                          trailing: IconButton(
                            tooltip: 'E-Mail kopieren',
                            onPressed: () async {
                              await Clipboard.setData(
                                const ClipboardData(text: supportEmail),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('E-Mail-Adresse kopiert.'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () => _requestDeletion(context),
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Löschanfrage per E-Mail senden'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Zur FREIRAUM Anmeldung'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
