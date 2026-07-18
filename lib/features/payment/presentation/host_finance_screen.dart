import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_motion.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../data/payment_repository.dart';

class HostFinanceScreen extends ConsumerStatefulWidget {
  const HostFinanceScreen({super.key});

  @override
  ConsumerState<HostFinanceScreen> createState() => _HostFinanceScreenState();
}

class _HostFinanceScreenState extends ConsumerState<HostFinanceScreen> {
  late Future<_FinanceData> future = _load();
  final paymentUrl = TextEditingController();
  final iban = TextEditingController();
  final accountHolder = TextEditingController();
  final instructions = TextEditingController();
  String method = 'paypal';
  bool enabled = true;
  bool seeded = false;
  bool saving = false;
  final Set<String> deciding = {};

  Future<_FinanceData> _load() async {
    final repository = ref.read(paymentRepositoryProvider);
    final values = await Future.wait<dynamic>([
      repository.finance(),
      repository.directSettings(),
      repository.pendingDirectPayments(),
    ]);
    return _FinanceData(
      values[0] as HostFinanceSnapshot,
      values[1] as DirectPaymentSettings,
      values[2] as List<PendingDirectPayment>,
    );
  }

  void _reload() {
    seeded = false;
    setState(() => future = _load());
  }

  @override
  void dispose() {
    paymentUrl.dispose();
    iban.dispose();
    accountHolder.dispose();
    instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Zahlungen & Bestätigungen',
        subtitle: 'Direkte Zahlung an dich einrichten und Buchungen bestätigen.',
        activePath: '/host',
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go('/host'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Zum Dashboard'),
          ),
        ],
        child: FutureBuilder<_FinanceData>(
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
            _seed(snapshot.data!.settings);
            return _content(snapshot.data!);
          },
        ),
      );

  void _seed(DirectPaymentSettings value) {
    if (seeded) return;
    seeded = true;
    method = value.method;
    enabled = value.enabled;
    paymentUrl.text = value.paymentUrl ?? '';
    iban.text = value.iban ?? '';
    accountHolder.text = value.accountHolder ?? '';
    instructions.text = value.instructions ?? '';
  }

  Widget _content(_FinanceData data) => RefreshIndicator(
        onRefresh: () async {
          _reload();
          await future;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MotionReveal(child: _hero(data)),
                    const SizedBox(height: 18),
                    MotionReveal(
                      delay: const Duration(milliseconds: 70),
                      child: _settingsCard(data.settings),
                    ),
                    const SizedBox(height: 22),
                    MotionReveal(
                      delay: const Duration(milliseconds: 110),
                      child: _pendingCard(data.pending),
                    ),
                    const SizedBox(height: 22),
                    MotionReveal(
                      delay: const Duration(milliseconds: 150),
                      child: _transactions(data.finance.transactions),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _hero(_FinanceData data) {
    final refunds = data.finance.transactions
        .where((item) => item.status == 'refund_required')
        .length;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [T.ink, T.inkSoft, Color(0xFF12354A)],
        ),
        borderRadius: BorderRadius.circular(T.radiusSpacious),
        boxShadow: T.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: T.mint, size: 42),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direkte Zahlungen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Der Mieter bezahlt dich direkt. FREIRAUM hält kein Geld.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DarkMetric(_money(data.finance.grossPaidCents), 'bestätigt'),
              _DarkMetric('${data.pending.length}', 'zu prüfen'),
              _DarkMetric('$refunds', 'manuell zu erstatten'),
              _DarkMetric(
                data.settings.configured ? 'Aktiv' : 'Fehlt',
                'Zahlungsmethode',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settingsCard(DirectPaymentSettings current) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: current.configured ? T.mint : T.line),
          boxShadow: T.shadowSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Zahlungsmethode für Mieter',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const Text(
              'Hinterlege genau das Ziel, an das Mieter direkt bezahlen sollen.',
              style: TextStyle(color: T.muted),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: method,
              decoration: const InputDecoration(
                labelText: 'Zahlungsart',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'paypal', child: Text('PayPal')),
                DropdownMenuItem(value: 'revolut', child: Text('Revolut')),
                DropdownMenuItem(value: 'sepa', child: Text('SEPA-Überweisung')),
              ],
              onChanged: saving
                  ? null
                  : (value) => setState(() => method = value ?? 'paypal'),
            ),
            const SizedBox(height: 14),
            if (method == 'paypal' || method == 'revolut')
              TextField(
                controller: paymentUrl,
                enabled: !saving,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: method == 'paypal'
                      ? 'PayPal.Me- oder Business-Link'
                      : 'Revolut-Zahlungslink',
                  prefixIcon: const Icon(Icons.link),
                  hintText: 'https://…',
                ),
              ),
            if (method == 'sepa') ...[
              TextField(
                controller: accountHolder,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Kontoinhaber',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: iban,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'IBAN',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: instructions,
              enabled: !saving,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Optionale Hinweise',
                hintText: 'Zum Beispiel: Bitte als Waren und Dienstleistungen zahlen.',
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: enabled,
              onChanged: saving ? null : (value) => setState(() => enabled = value),
              title: const Text('Direktzahlung aktivieren'),
              subtitle: const Text(
                'Ohne aktive Zahlungsmethode können deine Stellplätze nicht gebucht werden.',
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: saving ? null : _saveSettings,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'Wird gespeichert …' : 'Zahlungsmethode speichern'),
              ),
            ),
          ],
        ),
      );

  Widget _pendingCard(List<PendingDirectPayment> values) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: values.isEmpty ? T.line : T.amber),
          boxShadow: T.shadowSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Zahlungseingänge bestätigen',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                ),
                if (values.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: T.amberSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('${values.length} offen'),
                  ),
              ],
            ),
            const Text(
              'Prüfe den Eingang in deinem PayPal-, Revolut- oder Bankkonto.',
              style: TextStyle(color: T.muted),
            ),
            const SizedBox(height: 16),
            if (values.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    Icon(Icons.verified_outlined, size: 48, color: T.success),
                    SizedBox(height: 8),
                    Text('Keine Zahlung wartet auf Bestätigung.'),
                  ],
                ),
              )
            else
              ...values.map(_pendingTile),
          ],
        ),
      );

  Widget _pendingTile(PendingDirectPayment item) {
    final working = deciding.contains(item.paymentId);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: T.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: T.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                item.parkingTitle,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(item.bookingReference, style: const TextStyle(color: T.muted)),
              Text(_money(item.amountCents)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${item.renterName} · ${item.vehiclePlate}'),
          Text(
            '${_date(item.start)} – ${_date(item.end)}',
            style: const TextStyle(color: T.muted),
          ),
          const SizedBox(height: 10),
          SelectableText(
            'Zahlungsreferenz: ${item.payerReference}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: working ? null : () => _reject(item),
                icon: const Icon(Icons.close),
                label: const Text('Nicht erhalten'),
              ),
              FilledButton.icon(
                onPressed: working ? null : () => _decide(item, 'confirm'),
                icon: working
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Zahlung bestätigen'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _transactions(List<HostFinanceTransaction> values) => Container(
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
            const Text(
              'Zahlungsverlauf',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const Text(
              'FREIRAUM dokumentiert den Status, führt aber keine Überweisung aus.',
              style: TextStyle(color: T.muted),
            ),
            const SizedBox(height: 16),
            if (values.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('Noch keine Zahlungen')),
              )
            else
              ...values.take(50).map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        item.status == 'paid'
                            ? Icons.check_circle_outline
                            : item.status == 'refund_required'
                                ? Icons.undo_outlined
                                : Icons.schedule_outlined,
                        color: item.status == 'paid' ? T.success : T.warning,
                      ),
                      title: Text('Buchung ${item.bookingId.substring(0, 8)}'),
                      subtitle: Text(_statusLabel(item.status)),
                      trailing: Text(
                        _money(item.amountCents),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
          ],
        ),
      );

  Future<void> _saveSettings() async {
    setState(() => saving = true);
    try {
      await ref.read(paymentRepositoryProvider).saveDirectSettings(
            DirectPaymentSettings(
              method: method,
              enabled: enabled,
              configured: true,
              paymentUrl: paymentUrl.text,
              iban: iban.text,
              accountHolder: accountHolder.text,
              instructions: instructions.text,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zahlungsmethode gespeichert.')),
        );
        _reload();
      }
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

  Future<void> _reject(PendingDirectPayment item) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zahlung nicht erhalten?'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Kurze Begründung'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text.trim().isEmpty
                  ? 'Zahlung konnte nicht gefunden werden.'
                  : controller.text.trim(),
            ),
            child: const Text('Ablehnen'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason != null) await _decide(item, 'reject', reason: reason);
  }

  Future<void> _decide(
    PendingDirectPayment item,
    String decision, {
    String? reason,
  }) async {
    setState(() => deciding.add(item.paymentId));
    try {
      await ref.read(paymentRepositoryProvider).decideDirectPayment(
            item.paymentId,
            decision,
            reason: reason,
          );
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => deciding.remove(item.paymentId));
    }
  }
}

class _FinanceData {
  const _FinanceData(this.finance, this.settings, this.pending);

  final HostFinanceSnapshot finance;
  final DirectPaymentSettings settings;
  final List<PendingDirectPayment> pending;
}

class _DarkMetric extends StatelessWidget {
  const _DarkMetric(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        width: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withOpacity(.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(label, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );
}

String _money(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _statusLabel(String value) => switch (value) {
      'paid' => 'Vom Anbieter bestätigt',
      'awaiting_payment' => 'Wartet auf Zahlung',
      'awaiting_host_confirmation' => 'Wartet auf deine Bestätigung',
      'refund_required' => 'Direkte Rückerstattung erforderlich',
      'refunded' => 'Erstattet',
      'rejected' => 'Nicht bestätigt',
      'cancelled' => 'Storniert',
      'failed' => 'Fehlgeschlagen',
      'expired' => 'Abgelaufen',
      _ => 'In Bearbeitung',
    };
