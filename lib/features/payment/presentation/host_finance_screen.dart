import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
  late Future<HostFinanceSnapshot> future = _load();
  bool opening = false;

  Future<HostFinanceSnapshot> _load() =>
      ref.read(paymentRepositoryProvider).finance();

  void _reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Finanzen & Auszahlungen',
        subtitle: 'Umsatz, Plattformgebühr und Auszahlungskonto verwalten.',
        activePath: '/host',
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go('/host'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Zum Dashboard'),
          ),
        ],
        child: FutureBuilder<HostFinanceSnapshot>(
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

  Widget _content(HostFinanceSnapshot data) => RefreshIndicator(
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
                      child: _connectCard(data.connect),
                    ),
                    const SizedBox(height: 24),
                    MotionReveal(
                      delay: const Duration(milliseconds: 120),
                      child: _transactions(data.transactions),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _hero(HostFinanceSnapshot data) => Container(
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
                Icon(Icons.account_balance_wallet_outlined, color: T.mint, size: 40),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deine FREIRAUM Finanzen',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Alle Beträge werden in Cent-genauer Plattformbuchhaltung geführt.',
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
                _DarkMetric(_money(data.grossPaidCents), 'bezahlter Umsatz'),
                _DarkMetric(_money(data.platformFeeCents), 'Plattformgebühr'),
                _DarkMetric(_money(data.hostNetCents), 'dein Netto'),
                _DarkMetric(_money(data.pendingCents), 'in Bearbeitung'),
                _DarkMetric(_money(data.refundedCents), 'erstattet'),
              ],
            ),
          ],
        ),
      );

  Widget _connectCard(ConnectStatus connect) {
    final title = connect.mode == 'beta'
        ? 'Beta-Zahlungsmodus'
        : connect.ready
            ? 'Auszahlungskonto ist aktiv'
            : connect.connected
                ? 'Stripe-Konto vervollständigen'
                : 'Auszahlungskonto verbinden';
    final message = connect.mode == 'beta'
        ? 'Buchungen werden aktuell ohne echte Belastung bestätigt. Für Live-Zahlungen müssen Stripe-Schlüssel hinterlegt und PAYMENT_MODE=stripe aktiviert werden.'
        : connect.ready
            ? 'Zahlungen können automatisch abzüglich der Plattformgebühr an dein Stripe-Konto weitergeleitet werden.'
            : connect.configured
                ? 'Schließe die Identitäts- und Bankprüfung bei Stripe ab, damit Auszahlungen aktiviert werden.'
                : 'Stripe ist auf dem Server noch nicht konfiguriert.';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.circular(T.radius),
        border: Border.all(color: connect.ready ? T.mint : T.line),
        boxShadow: T.shadowSmall,
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: connect.ready ? T.mintSoft : T.porcelainDeep,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              connect.ready
                  ? Icons.verified_outlined
                  : Icons.account_balance_outlined,
              color: connect.ready ? T.success : T.muted,
            ),
          ),
          SizedBox(
            width: 650,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(message, style: const TextStyle(color: T.muted)),
              ],
            ),
          ),
          if (connect.mode != 'beta' && connect.configured)
            FilledButton.icon(
              onPressed: opening
                  ? null
                  : connect.ready
                      ? _openDashboard
                      : _openOnboarding,
              icon: Icon(
                connect.ready ? Icons.open_in_new : Icons.arrow_forward,
              ),
              label: Text(
                opening
                    ? 'Wird geöffnet …'
                    : connect.ready
                        ? 'Stripe Dashboard'
                        : 'Jetzt verbinden',
              ),
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
              'Transaktionen',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const Text(
              'Zahlungen, Gebühren, Erstattungen und dein Nettoanteil.',
              style: TextStyle(color: T.muted),
            ),
            const SizedBox(height: 16),
            if (values.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 34),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 54, color: T.muted),
                    SizedBox(height: 10),
                    Text('Noch keine Zahlungstransaktionen'),
                  ],
                ),
              )
            else
              ...values.map(_transactionTile),
          ],
        ),
      );

  Widget _transactionTile(HostFinanceTransaction item) {
    final refunded = item.status == 'refunded';
    final paid = item.status == 'paid';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: T.line),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            refunded
                ? Icons.undo_outlined
                : paid
                    ? Icons.check_circle_outline
                    : Icons.schedule_outlined,
            color: refunded
                ? T.warning
                : paid
                    ? T.success
                    : T.muted,
          ),
          SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buchung ${item.bookingId.substring(0, 8)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  _statusLabel(item.status),
                  style: const TextStyle(color: T.muted),
                ),
              ],
            ),
          ),
          _Amount(label: 'Brutto', cents: item.amountCents),
          _Amount(label: 'Gebühr', cents: item.platformFeeCents),
          _Amount(label: 'Netto', cents: item.hostNetCents, strong: true),
        ],
      ),
    );
  }

  Future<void> _openOnboarding() => _open(
        () => ref.read(paymentRepositoryProvider).onboardingLink(),
      );

  Future<void> _openDashboard() => _open(
        () => ref.read(paymentRepositoryProvider).dashboardLink(),
      );

  Future<void> _open(Future<Uri> Function() createLink) async {
    setState(() => opening = true);
    try {
      final uri = await createLink();
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );
      if (!opened) throw StateError('Link konnte nicht geöffnet werden.');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }
}

class _DarkMetric extends StatelessWidget {
  const _DarkMetric(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        width: 180,
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

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.cents, this.strong = false});

  final String label;
  final int cents;
  final bool strong;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(label, style: const TextStyle(color: T.muted, fontSize: 12)),
            Text(
              _money(cents),
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

String _money(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

String _statusLabel(String value) => switch (value) {
      'paid' => 'Bezahlt',
      'refunded' => 'Erstattet',
      'refund_pending' => 'Erstattung läuft',
      'checkout_created' => 'Zahlung geöffnet',
      'failed' => 'Fehlgeschlagen',
      'expired' => 'Abgelaufen',
      _ => 'In Bearbeitung',
    };
