import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../host/data/host_repository.dart';
import '../data/trust_repository.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final statement = TextEditingController();
  String? selectedId;
  bool busy = false;

  @override
  void dispose() {
    statement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Stellplatzprüfung',
        subtitle: 'Berechtigung für ein Angebot bestätigen.',
        activePath: '/trust',
        actions: [
          IconButton(
            onPressed: () => context.go('/trust'),
            icon: const Icon(Icons.close),
          ),
        ],
        child: FutureBuilder<List<HostSpaceRecord>>(
          future: ref.read(hostRepositoryProvider).spaces(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final spaces = snapshot.data!;
            if (spaces.isEmpty) {
              return const Center(
                child: Text('Lege zuerst einen Stellplatz an.'),
              );
            }
            selectedId ??= spaces.first.id;
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
                          value: selectedId,
                          decoration: const InputDecoration(
                            labelText: 'Stellplatz',
                          ),
                          items: spaces
                              .map(
                                (space) => DropdownMenuItem(
                                  value: space.id,
                                  child: Text(space.title),
                                ),
                              )
                              .toList(),
                          onChanged: busy
                              ? null
                              : (value) => setState(() => selectedId = value),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: statement,
                          minLines: 5,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Berechtigung beschreiben',
                            hintText:
                                'Beschreibe, warum du den Stellplatz anbieten darfst.',
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: busy ? null : () => _submit(context),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Prüfung beantragen'),
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

  Future<void> _submit(BuildContext context) async {
    final text = statement.text.trim();
    if (selectedId == null || text.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte ergänze eine kurze Beschreibung.')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await ref.read(trustRepositoryProvider).submitVerification(
            parkingSpaceId: selectedId!,
            statement: text,
          );
      if (mounted) context.go('/trust');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
