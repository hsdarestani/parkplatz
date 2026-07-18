import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/authenticated_error_state.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../parking/data/providers.dart';
import '../data/repositories.dart';

class DirectMyBookingsScreen extends ConsumerStatefulWidget {
  const DirectMyBookingsScreen({super.key});

  @override
  ConsumerState<DirectMyBookingsScreen> createState() =>
      _DirectMyBookingsScreenState();
}

class _DirectMyBookingsScreenState
    extends ConsumerState<DirectMyBookingsScreen> {
  late Future<List<BookingRecord>> future = _load();
  final Set<String> cancelling = {};

  Future<List<BookingRecord>> _load() =>
      ref.read(bookingRepositoryProvider).all();

  void _reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Meine Buchungen',
        subtitle: 'Zahlungsprüfung, Parking Pass und Stornierungen verwalten.',
        activePath: '/bookings',
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/discover'),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Stellplatz finden'),
          ),
        ],
        child: FutureBuilder<List<BookingRecord>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AuthenticatedErrorState(
                error: snapshot.error,
                onRetry: _reload,
                returnTo: '/bookings',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _content(snapshot.data!);
          },
        ),
      );

  Widget _content(List<BookingRecord> values) {
    final now = DateTime.now();
    final pending = values
        .where(
          (booking) => booking.status == 'pending' && booking.end.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final confirmed = values
        .where(
          (booking) =>
              booking.status == 'confirmed' && booking.end.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final history = values
        .where(
          (booking) => !pending.contains(booking) && !confirmed.contains(booking),
        )
        .toList()
      ..sort((a, b) => b.start.compareTo(a.start));

    return RefreshIndicator(
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
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hero(pending.length, confirmed.length, history.length),
                  const SizedBox(height: 24),
                  if (values.isEmpty)
                    _empty()
                  else ...[
                    if (pending.isNotEmpty) ...[
                      _section(
                        'Wartet auf Bestätigung',
                        'Der Anbieter prüft den direkten Zahlungseingang.',
                      ),
                      const SizedBox(height: 12),
                      ...pending.map(
                        (booking) => _card(
                          booking,
                          pending: true,
                          cancellable: true,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    if (confirmed.isNotEmpty) ...[
                      _section(
                        'Bestätigte Buchungen',
                        'Adresse, Zufahrt und Parking Pass sind freigeschaltet.',
                      ),
                      const SizedBox(height: 12),
                      ...confirmed.map(
                        (booking) => _card(
                          booking,
                          cancellable: true,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    if (history.isNotEmpty) ...[
                      _section('Verlauf', 'Stornierte, abgelaufene und vergangene Buchungen.'),
                      const SizedBox(height: 12),
                      ...history.map(_card),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(int pending, int confirmed, int history) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [T.ink, T.inkSoft]),
          borderRadius: BorderRadius.circular(T.radiusSpacious),
          boxShadow: T.shadow,
        ),
        child: Wrap(
          spacing: 20,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              color: T.mint,
              size: 50,
            ),
            const SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deine Buchungen im Überblick',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Direkte Zahlungen werden erst nach Prüfung durch den Anbieter bestätigt.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            _metric('$pending', 'in Prüfung'),
            _metric('$confirmed', 'bestätigt'),
            _metric('$history', 'im Verlauf'),
          ],
        ),
      );

  Widget _metric(String value, String label) => Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(16),
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

  Widget _section(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          Text(subtitle, style: const TextStyle(color: T.muted)),
        ],
      );

  Widget _card(
    BookingRecord booking, {
    bool pending = false,
    bool cancellable = false,
  }) {
    final confirmed = booking.status == 'confirmed';
    final cancelled = booking.status == 'cancelled';
    final color = confirmed
        ? T.success
        : pending
            ? T.warning
            : T.muted;
    final background = confirmed
        ? T.mintSoft
        : pending
            ? T.amberSoft
            : T.porcelainDeep;
    final busy = cancelling.contains(booking.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.circular(T.radius),
        border: Border.all(color: T.line),
        boxShadow: T.shadowSmall,
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              confirmed
                  ? Icons.local_parking_rounded
                  : pending
                      ? Icons.hourglass_top_rounded
                      : Icons.event_busy_outlined,
              color: color,
            ),
          ),
          SizedBox(
            width: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(
                  '${_date(booking.start)} – ${_time(booking.end)}',
                  style: const TextStyle(color: T.muted),
                ),
                Text(
                  '${booking.plate} · ${booking.reference}',
                  style: const TextStyle(color: T.muted),
                ),
                const SizedBox(height: 5),
                Text(
                  pending
                      ? 'Zahlung eingereicht – Anbieterbestätigung ausstehend'
                      : _statusLabel(booking.status),
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                if (cancelled)
                  const Text(
                    'Eine bereits direkt gezahlte Buchung muss der Anbieter manuell erstatten.',
                    style: TextStyle(color: T.muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          Text(
            _money(booking.totalCents),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          if (confirmed)
            FilledButton.tonalIcon(
              onPressed: () => context.go('/bookings/${booking.id}/pass'),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Parking Pass'),
            ),
          if (cancellable)
            TextButton.icon(
              onPressed: busy ? null : () => _cancel(booking),
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.close),
              label: const Text('Stornieren'),
            ),
        ],
      ),
    );
  }

  Widget _empty() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 58),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
        ),
        child: const Column(
          children: [
            Icon(Icons.event_available_outlined, size: 64, color: T.muted),
            SizedBox(height: 12),
            Text(
              'Noch keine Buchungen',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );

  Future<void> _cancel(BookingRecord booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buchung stornieren?'),
        content: Text(
          booking.status == 'confirmed'
              ? 'Der Anbieter muss eine direkte Zahlung anschließend manuell erstatten.'
              : 'Die offene Buchungsanfrage wird beendet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Behalten'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stornieren'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => cancelling.add(booking.id));
    try {
      await ref.read(bookingRepositoryProvider).cancel(booking.id);
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => cancelling.remove(booking.id));
    }
  }
}

String _money(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} ${_time(local)}';
}

String _time(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} Uhr';
}

String _statusLabel(String value) => switch (value) {
      'confirmed' => 'Bestätigt',
      'cancelled' => 'Storniert',
      'completed' => 'Abgeschlossen',
      'expired' => 'Abgelaufen',
      'pending' => 'Wartet auf Bestätigung',
      _ => value,
    };
