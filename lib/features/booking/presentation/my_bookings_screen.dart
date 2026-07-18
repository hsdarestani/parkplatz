import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/authenticated_error_state.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../parking/data/providers.dart';
import '../data/repositories.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  late Future<List<BookingRecord>> bookings;

  @override
  void initState() {
    super.initState();
    bookings = _load();
  }

  Future<List<BookingRecord>> _load() =>
      ref.read(bookingRepositoryProvider).all();

  void _reload() => setState(() => bookings = _load());

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Meine Buchungen',
        subtitle: 'Reservierungen, Parking Passes und Verlauf verwalten.',
        activePath: '/bookings',
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/discover'),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Stellplatz finden'),
          ),
        ],
        child: FutureBuilder<List<BookingRecord>>(
          future: bookings,
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
    final active = values
        .where(
          (booking) =>
              booking.status == 'confirmed' && booking.end.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final history = values.where((booking) => !active.contains(booking)).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    final activeTotal = active.fold<int>(
      0,
      (sum, booking) => sum + booking.totalCents,
    );

    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await bookings;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryBanner(
                    activeCount: active.length,
                    historyCount: history.length,
                    activeTotal: activeTotal,
                  ),
                  const SizedBox(height: 24),
                  if (values.isEmpty)
                    const _EmptyBookings()
                  else ...[
                    if (active.isNotEmpty) ...[
                      const _SectionHeader(
                        title: 'Aktuelle Buchungen',
                        subtitle: 'Anstehende und laufende Reservierungen',
                      ),
                      const SizedBox(height: 12),
                      ...active.map(
                        (booking) => _BookingCard(
                          booking: booking,
                          onCancel: () => _cancel(booking),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    if (history.isNotEmpty) ...[
                      const _SectionHeader(
                        title: 'Verlauf',
                        subtitle: 'Stornierte und vergangene Reservierungen',
                      ),
                      const SizedBox(height: 12),
                      ...history.map(
                        (booking) => _BookingCard(
                          booking: booking,
                          onCancel: null,
                        ),
                      ),
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

  Future<void> _cancel(BookingRecord booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buchung stornieren?'),
        content: Text(
          '${booking.title} am ${_date(booking.start)} wird storniert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Behalten'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Stornieren'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(bookingRepositoryProvider).cancel(booking.id);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buchung wurde storniert.')),
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
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.activeCount,
    required this.historyCount,
    required this.activeTotal,
  });

  final int activeCount;
  final int historyCount;
  final int activeTotal;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [T.ink, T.inkSoft]),
          borderRadius: BorderRadius.circular(T.radiusSpacious),
          boxShadow: T.shadow,
        ),
        child: Wrap(
          spacing: 28,
          runSpacing: 18,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              color: T.mint,
              size: 52,
            ),
            const SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alles für deine nächste Ankunft',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Parking Pass, Fahrzeug, Zeitraum und Stornierung an einem Ort.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            _SummaryMetric('$activeCount', 'aktiv'),
            _SummaryMetric('$historyCount', 'im Verlauf'),
            _SummaryMetric(_money(activeTotal), 'offener Wert'),
          ],
        ),
      );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        width: 120,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(16),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          Text(subtitle, style: const TextStyle(color: T.muted)),
        ],
      );
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onCancel});

  final BookingRecord booking;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final confirmed = booking.status == 'confirmed';
    final cancelled = booking.status == 'cancelled';
    final statusColor = confirmed
        ? T.success
        : cancelled
            ? T.muted
            : T.warning;
    final statusBackground = confirmed
        ? T.mintSoft
        : cancelled
            ? T.porcelainDeep
            : T.amberSoft;
    final statusLabel = confirmed
        ? 'Bestätigt'
        : cancelled
            ? 'Storniert'
            : booking.status;

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
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(
              confirmed
                  ? Icons.local_parking_rounded
                  : Icons.event_busy_outlined,
              color: statusColor,
              size: 30,
            ),
          ),
          SizedBox(
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      booking.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${_date(booking.start)} – ${_time(booking.end)}',
                  style: const TextStyle(color: T.muted),
                ),
                Text(
                  '${booking.plate} · ${booking.reference}',
                  style: const TextStyle(
                    color: T.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              _money(booking.totalCents),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
          ),
          if (confirmed)
            FilledButton.tonalIcon(
              onPressed: () => context.go('/bookings/${booking.id}/pass'),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Parking Pass'),
            ),
          if (onCancel != null)
            TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close),
              label: const Text('Stornieren'),
            ),
        ],
      ),
    );
  }
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 58),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.event_available_outlined,
              size: 68,
              color: T.muted,
            ),
            const SizedBox(height: 14),
            const Text(
              'Noch keine Buchungen',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const Text(
              'Finde einen passenden Stellplatz und reserviere ihn in wenigen Schritten.',
              textAlign: TextAlign.center,
              style: TextStyle(color: T.muted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/discover'),
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Stellplatz entdecken'),
            ),
          ],
        ),
      );
}

String _money(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} · ${_time(local)}';
}

String _time(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
