import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../parking/data/providers.dart';
import '../data/account_controls_repository.dart';

class AccountControlsScreen extends ConsumerStatefulWidget {
  const AccountControlsScreen({super.key});

  @override
  ConsumerState<AccountControlsScreen> createState() =>
      _AccountControlsScreenState();
}

class _AccountControlsScreenState extends ConsumerState<AccountControlsScreen> {
  late Future<NotificationPreferences> future = _load();
  bool saving = false;

  Future<NotificationPreferences> _load() =>
      ref.read(accountControlsRepositoryProvider).notificationPreferences();

  void _reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Sicherheit & Datenschutz',
        subtitle: 'Benachrichtigungen, Passwort und Kontodaten verwalten.',
        activePath: '/profile',
        actions: [
          IconButton(
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.close),
          ),
        ],
        child: FutureBuilder<NotificationPreferences>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: FilledButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: Text(snapshot.error.toString()),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _content(snapshot.data!);
          },
        ),
      );

  Widget _content(NotificationPreferences preferences) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 20),
                  Text(
                    'E-Mail-Benachrichtigungen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Column(
                      children: [
                        _switch(
                          'Buchungsupdates',
                          'Bestätigung, Stornierung und Erstattung',
                          preferences.bookingUpdates,
                          (value) => _save(
                            preferences.copyWith(bookingUpdates: value),
                          ),
                        ),
                        _switch(
                          'Vermieter-Updates',
                          'Neue oder stornierte Buchungen deiner Stellplätze',
                          preferences.hostUpdates,
                          (value) => _save(
                            preferences.copyWith(hostUpdates: value),
                          ),
                        ),
                        _switch(
                          'Prüfung & Support',
                          'Verifizierung und Supportanfragen',
                          preferences.trustUpdates,
                          (value) => _save(
                            preferences.copyWith(trustUpdates: value),
                          ),
                        ),
                        _switch(
                          'Sicherheitsmeldungen',
                          'Passwort- und Kontoänderungen',
                          preferences.securityUpdates,
                          (value) => _save(
                            preferences.copyWith(securityUpdates: value),
                          ),
                        ),
                        _switch(
                          'Produktneuigkeiten',
                          'Freiwillige Informationen zu FREIRAUM',
                          preferences.marketing,
                          (value) => _save(
                            preferences.copyWith(marketing: value),
                          ),
                          divider: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Kontosicherheit',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  _actionCard(
                    icon: Icons.password_outlined,
                    title: 'Passwort ändern',
                    subtitle: 'Alle bestehenden Sitzungen werden danach beendet.',
                    onTap: _changePassword,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Deine Daten',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  _actionCard(
                    icon: Icons.download_outlined,
                    title: 'Datenexport erstellen',
                    subtitle: 'Profil, Fahrzeuge, Buchungen und Zahlungen als JSON.',
                    onTap: _exportData,
                  ),
                  const SizedBox(height: 10),
                  _actionCard(
                    icon: Icons.delete_forever_outlined,
                    title: 'Konto löschen',
                    subtitle:
                        'Profil wird anonymisiert. Gesetzlich notwendige Buchungsdaten bleiben ohne persönliche Profildaten erhalten.',
                    onTap: _deleteAccount,
                    danger: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _header() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [T.ink, T.inkSoft]),
          borderRadius: BorderRadius.circular(T.radiusSpacious),
          boxShadow: T.shadow,
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, color: T.mint, size: 44),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Du kontrollierst deine Daten',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Transparente Einstellungen nach DSGVO-Grundsätzen.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _switch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool divider = true,
  }) =>
      Column(
        children: [
          SwitchListTile(
            value: value,
            onChanged: saving ? null : onChanged,
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(subtitle),
          ),
          if (divider) const Divider(height: 1),
        ],
      );

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) =>
      Card(
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: danger ? Theme.of(context).colorScheme.error : T.success),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );

  Future<void> _save(NotificationPreferences value) async {
    setState(() => saving = true);
    try {
      await ref
          .read(accountControlsRepositoryProvider)
          .saveNotificationPreferences(value);
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Passwort ändern'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Aktuelles Passwort'),
            ),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Neues Passwort'),
            ),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passwort wiederholen'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (next.text.length >= 8 && next.text == confirm.text) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Ändern'),
          ),
        ],
      ),
    );
    if (submitted == true) {
      try {
        await ref.read(accountControlsRepositoryProvider).changePassword(
              current.text,
              next.text,
            );
        await ref.read(authRepositoryProvider).logout();
        if (mounted) context.go('/login?password=changed');
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      }
    }
    current.dispose();
    next.dispose();
    confirm.dispose();
  }

  Future<void> _exportData() async {
    try {
      final data = await ref.read(accountControlsRepositoryProvider).exportData();
      final formatted = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: formatted));
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Datenexport erstellt'),
            content: const Text(
              'Der vollständige JSON-Export wurde in die Zwischenablage kopiert.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fertig'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konto endgültig löschen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Aktive Buchungen müssen zuerst beendet oder storniert werden. Gib dein Passwort und DELETE ein.',
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passwort'),
            ),
            TextField(
              controller: confirmation,
              decoration: const InputDecoration(labelText: 'DELETE'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(
              dialogContext,
              confirmation.text.trim() == 'DELETE',
            ),
            child: const Text('Konto löschen'),
          ),
        ],
      ),
    );
    if (submitted == true) {
      try {
        await ref
            .read(accountControlsRepositoryProvider)
            .deleteAccount(password.text);
        await ref.read(authRepositoryProvider).logout();
        if (mounted) context.go('/login?account=deleted');
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      }
    }
    password.dispose();
    confirmation.dispose();
  }
}
