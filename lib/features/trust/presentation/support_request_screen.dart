import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../host/data/host_repository.dart';
import '../../parking/data/providers.dart';
import '../data/trust_repository.dart';

class SupportRequestScreen extends ConsumerStatefulWidget {
  const SupportRequestScreen({super.key});

  @override
  ConsumerState<SupportRequestScreen> createState() =>
      _SupportRequestScreenState();
}

class _SupportRequestScreenState extends ConsumerState<SupportRequestScreen> {
  final description = TextEditingController();
  String? target;
  String category = 'access_problem';
  bool busy = false;

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Supportanfrage',
        subtitle: 'Problem zu einer Buchung oder einem Stellplatz melden.',
        activePath: '/trust',
        child: FutureBuilder<List<MapEntry<String, String>>>(
          future: _targets(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final targets = snapshot.data!;
            if (targets.isEmpty) {
              return const Center(child: Text('Keine passenden Einträge vorhanden.'));
            }
            target ??= targets.first.key;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: target,
                          decoration: const InputDecoration(labelText: 'Bezug'),
                          items: targets
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (value) => setState(() => target = value),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(labelText: 'Kategorie'),
                          items: const [
                            DropdownMenuItem(
                              value: 'access_problem',
                              child: Text('Zugang'),
                            ),
                            DropdownMenuItem(
                              value: 'incorrect_listing',
                              child: Text('Angaben'),
                            ),
                            DropdownMenuItem(
                              value: 'payment_issue',
                              child: Text('Zahlung'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Sonstiges'),
                            ),
                          ],
                          onChanged: busy
                              ? null
                              : (value) => setState(
                                    () => category = value ?? category,
                                  ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: description,
                          minLines: 5,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Beschreibung',
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: busy ? null : () => _submit(context),
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Anfrage senden'),
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

  Future<List<MapEntry<String, String>>> _targets() async {
    final bookings = await ref.read(bookingRepositoryProvider).all();
    final spaces = await ref.read(hostRepositoryProvider).spaces();
    return [
      ...bookings.map((value) => MapEntry('booking:${value.id}', value.title)),
      ...spaces.map((value) => MapEntry('space:${value.id}', value.title)),
    ];
  }

  Future<void> _submit(BuildContext context) async {
    final text = description.text.trim();
    if (target == null || text.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte beschreibe das Problem genauer.')),
      );
      return;
    }
    setState(() => busy = true);
    final parts = target!.split(':');
    try {
      await ref.read(trustRepositoryProvider).submitReport(
            bookingId: parts.first == 'booking' ? parts.last : null,
            parkingSpaceId: parts.first == 'space' ? parts.last : null,
            category: category,
            description: text,
          );
      if (mounted) context.go('/trust');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
