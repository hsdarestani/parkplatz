import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../data/trust_repository.dart';

class AdminTrustScreen extends ConsumerStatefulWidget {
  const AdminTrustScreen({super.key});

  @override
  ConsumerState<AdminTrustScreen> createState() => _AdminTrustScreenState();
}

class _AdminTrustScreenState extends ConsumerState<AdminTrustScreen> {
  late Future<AdminTrustQueue> future = _load();

  Future<AdminTrustQueue> _load() =>
      ref.read(trustRepositoryProvider).adminQueue();

  void reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Moderation',
        subtitle: 'Offene Prüfungen und Anfragen bearbeiten.',
        activePath: '/trust',
        actions: [
          IconButton(
            onPressed: () => context.go('/trust'),
            icon: const Icon(Icons.close),
          ),
        ],
        child: FutureBuilder<AdminTrustQueue>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: FilledButton.icon(
                  onPressed: reload,
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

  Widget _content(AdminTrustQueue data) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summary(data),
                  const SizedBox(height: 22),
                  Text(
                    'Stellplatzprüfungen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  if (data.verifications.isEmpty)
                    const _Empty(text: 'Keine offenen Prüfungen.')
                  else
                    ...data.verifications.map(_verificationCard),
                  const SizedBox(height: 22),
                  Text(
                    'Supportanfragen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  if (data.reports.isEmpty)
                    const _Empty(text: 'Keine offenen Anfragen.')
                  else
                    ...data.reports.map(_reportCard),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _summary(AdminTrustQueue data) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [T.ink, T.inkSoft]),
          borderRadius: BorderRadius.circular(T.radiusSpacious),
        ),
        child: Text(
          '${data.verifications.length} Prüfungen · ${data.reports.length} Anfragen',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

  Widget _verificationCard(VerificationRecord item) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.parkingTitle ?? item.parkingSpaceId,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(item.userEmail ?? ''),
              if (item.parkingAddress != null) Text(item.parkingAddress!),
              const SizedBox(height: 8),
              Text(item.statement),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => _reviewVerification(item, 'approved'),
                    icon: const Icon(Icons.check),
                    label: const Text('Freigeben'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _reviewVerification(item, 'rejected'),
                    icon: const Icon(Icons.close),
                    label: const Text('Ablehnen'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _reportCard(SafetyReportRecord item) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.category,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(item.userEmail ?? ''),
              const SizedBox(height: 8),
              Text(item.description),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                children: [
                  FilledButton(
                    onPressed: () => _reviewReport(item, 'resolved'),
                    child: const Text('Abschließen'),
                  ),
                  OutlinedButton(
                    onPressed: () => _reviewReport(item, 'triaged'),
                    child: const Text('In Prüfung'),
                  ),
                  TextButton(
                    onPressed: () => _reviewReport(item, 'dismissed'),
                    child: const Text('Schließen'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Future<String> _note(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Interne Notiz'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Ohne Notiz'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result ?? '';
  }

  Future<void> _reviewVerification(
    VerificationRecord item,
    String status,
  ) async {
    final note = await _note('Prüfung bearbeiten');
    await ref.read(trustRepositoryProvider).reviewVerification(
          item.id,
          status: status,
          note: note,
        );
    reload();
  }

  Future<void> _reviewReport(SafetyReportRecord item, String status) async {
    final note = await _note('Anfrage bearbeiten');
    await ref.read(trustRepositoryProvider).reviewReport(
          item.id,
          status: status,
          note: note,
        );
    reload();
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
        ),
        child: Text(text),
      );
}
