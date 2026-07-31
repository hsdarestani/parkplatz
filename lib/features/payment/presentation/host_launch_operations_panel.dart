import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../data/launch_operations_repository.dart';

class HostLaunchOperationsPanel extends ConsumerStatefulWidget {
  const HostLaunchOperationsPanel({super.key});

  @override
  ConsumerState<HostLaunchOperationsPanel> createState() =>
      _HostLaunchOperationsPanelState();
}

class _HostLaunchOperationsPanelState
    extends ConsumerState<HostLaunchOperationsPanel> {
  late Future<_LaunchData> future = _load();
  final Set<String> refunding = {};

  Future<_LaunchData> _load() async {
    final repository = ref.read(launchOperationsRepositoryProvider);
    final values = await Future.wait<dynamic>([
      repository.subscription(),
      repository.pendingRefunds(),
    ]);
    return _LaunchData(
      values[0] as HostSubscription,
      values[1] as List<ManualRefund>,
    );
  }

  void _reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<_LaunchData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _error(snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Center(child: LinearProgressIndicator());
          }
          final data = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _planCard(data.subscription),
              const SizedBox(height: 22),
              _refundCard(data.refunds),
            ],
          );
        },
      );

  Widget _error(String message) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
        ),
        child: Row(
          children: [
            Expanded(child: Text(message)),
            IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
          ],
        ),
      );

  Widget _planCard(HostSubscription subscription) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
          boxShadow: T.shadowSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: T.mintSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.local_parking_rounded,
                    color: T.success,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FREIRAUM Anbieter',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${subscription.listingLimit} Stellplatz${subscription.listingLimit == 1 ? '' : 'e'} · Bestätigung innerhalb von ${subscription.responseHours} Stunden',
                        style: const TextStyle(color: T.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: T.mintSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'AKTIV',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: subscription.features
                  .map(
                    (feature) => Chip(
                      avatar: const Icon(Icons.check, size: 17),
                      label: Text(feature),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              'In Version 1.0 werden keine kostenpflichtigen digitalen Upgrades oder Abonnements in der App angeboten.',
              style: TextStyle(color: T.muted),
            ),
          ],
        ),
      );

  Widget _refundCard(List<ManualRefund> refunds) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: refunds.isEmpty ? T.line : T.amber),
          boxShadow: T.shadowSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manuelle Rückerstattungen',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Erstatte direkt über PayPal, Revolut oder Bank und dokumentiere die Referenz.',
                        style: TextStyle(color: T.muted),
                      ),
                    ],
                  ),
                ),
                if (refunds.isNotEmpty)
                  Chip(label: Text('${refunds.length} offen')),
              ],
            ),
            const SizedBox(height: 16),
            if (refunds.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Column(
                  children: [
                    Icon(Icons.task_alt, color: T.success, size: 44),
                    SizedBox(height: 8),
                    Text('Keine Rückerstattung ist offen.'),
                  ],
                ),
              )
            else
              ...refunds.map(_refundTile),
          ],
        ),
      );

  Widget _refundTile(ManualRefund item) {
    final working = refunding.contains(item.paymentId);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: T.amberSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: T.amber),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.parkingTitle} · ${item.bookingReference}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text('${item.renterName} · ${item.renterEmail}'),
                Text(
                  '${launchMoney(item.amountCents)} über ${_method(item.paymentMethod)}',
                  style: const TextStyle(color: T.muted),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: working ? null : () => _completeRefund(item),
            icon: working
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.undo_rounded),
            label: const Text('Als erstattet markieren'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeRefund(ManualRefund item) async {
    final reference = TextEditingController();
    final note = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rückerstattung dokumentieren'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bitte zuerst ${launchMoney(item.amountCents)} direkt an ${item.renterName} erstatten.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reference,
                decoration: const InputDecoration(
                  labelText: 'Rückerstattungs- oder Transaktionsreferenz',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Optionale Notiz'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (reference.text.trim().length < 3) return;
              Navigator.pop(
                dialogContext,
                [reference.text.trim(), note.text.trim()],
              );
            },
            child: const Text('Rückerstattung bestätigen'),
          ),
        ],
      ),
    );
    reference.dispose();
    note.dispose();
    if (result == null) return;

    setState(() => refunding.add(item.paymentId));
    try {
      await ref.read(launchOperationsRepositoryProvider).completeRefund(
            item.paymentId,
            result.first,
            note: result.last,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rückerstattung wurde dokumentiert.')),
      );
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => refunding.remove(item.paymentId));
    }
  }
}

class _LaunchData {
  const _LaunchData(this.subscription, this.refunds);

  final HostSubscription subscription;
  final List<ManualRefund> refunds;
}

String _method(String value) => switch (value) {
      'paypal' => 'PayPal',
      'revolut' => 'Revolut',
      'sepa' => 'SEPA',
      _ => 'Direktzahlung',
    };
