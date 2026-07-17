import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../booking/data/repositories.dart';
import '../data/host_repository.dart';

class HostDashboardScreen extends ConsumerStatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  ConsumerState<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends ConsumerState<HostDashboardScreen> {
  late Future<_HostSnapshot> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<_HostSnapshot> _load() async {
    final repository = ref.read(hostRepositoryProvider);
    return _HostSnapshot(
      await repository.spaces(),
      await repository.bookings(),
    );
  }

  void reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Stellplatz vermieten',
        subtitle: 'Angebote, Buchungen und Verfügbarkeit verwalten.',
        activePath: '/host',
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/host/new'),
            icon: const Icon(Icons.add),
            label: const Text('Stellplatz hinzufügen'),
          ),
        ],
        child: FutureBuilder<_HostSnapshot>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: reload,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _content(snapshot.data!);
          },
        ),
      );

  Widget _content(_HostSnapshot snapshot) {
    final active = snapshot.spaces.where((space) => space.active).length;
    final confirmed = snapshot.bookings
        .where((booking) => booking.status == 'confirmed')
        .toList();
    final earnings = confirmed.fold<int>(
      0,
      (sum, booking) => sum + booking.totalCents,
    );

    return RefreshIndicator(
      onRefresh: () async {
        reload();
        await future;
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [T.ink, T.inkSoft],
                      ),
                      borderRadius: BorderRadius.circular(T.radiusSpacious),
                      boxShadow: T.shadow,
                    ),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 20,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_home_work_outlined,
                          color: T.mint,
                          size: 52,
                        ),
                        const SizedBox(
                          width: 520,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Freien Platz in Einkommen verwandeln',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Adresse bleibt geschützt. Du bestimmst Preis, Maße und Verfügbarkeit.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => context.go('/host/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('Jetzt hinzufügen'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _Metric('$active', 'aktive Stellplätze'),
                      _Metric('${confirmed.length}', 'offene Buchungen'),
                      _Metric(_money(earnings), 'Beta-Umsatz'),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Meine Stellplätze',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '${snapshot.spaces.length} Einträge',
                        style: const TextStyle(color: T.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.spaces.isEmpty)
                    _EmptyState(onAdd: () => context.go('/host/new'))
                  else
                    ...snapshot.spaces.map(
                      (space) => _SpaceCard(
                        space: space,
                        onStatusChanged: (status) => _setStatus(space, status),
                      ),
                    ),
                  if (snapshot.bookings.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Letzte Buchungen',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ...snapshot.bookings.take(5).map(_HostBookingTile.new),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(HostSpaceRecord space, String status) async {
    try {
      await ref.read(hostRepositoryProvider).setStatus(space.id, status);
      reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}

class _HostSnapshot {
  const _HostSnapshot(this.spaces, this.bookings);

  final List<HostSpaceRecord> spaces;
  final List<BookingRecord> bookings;
}

class _SpaceCard extends StatelessWidget {
  const _SpaceCard({
    required this.space,
    required this.onStatusChanged,
  });

  final HostSpaceRecord space;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) => Container(
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: space.active ? T.mintSoft : T.porcelainDeep,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                space.covered ? Icons.garage_outlined : Icons.local_parking,
                color: space.active ? T.success : T.muted,
              ),
            ),
            SizedBox(
              width: 470,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          space.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(label: Text(space.active ? 'Online' : 'Pausiert')),
                    ],
                  ),
                  Text(
                    '${space.district} · ${space.landmark}',
                    style: const TextStyle(color: T.muted),
                  ),
                  Text(
                    '${_money(space.hourlyPriceCents)} / Std. · ${space.maxLength.toStringAsFixed(1)} m Länge',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (!space.verified)
                    const Text(
                      'Noch nicht verifiziert',
                      style: TextStyle(color: T.warning),
                    ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: space.active
                  ? () => context.go('/parking/${space.id}')
                  : null,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Ansehen'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => onStatusChanged(
                space.active ? 'paused' : 'active',
              ),
              icon: Icon(space.active ? Icons.pause : Icons.play_arrow),
              label: Text(space.active ? 'Pausieren' : 'Aktivieren'),
            ),
          ],
        ),
      );
}

class _HostBookingTile extends StatelessWidget {
  const _HostBookingTile(this.booking);

  final BookingRecord booking;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: T.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_available_outlined, color: T.success),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${_date(booking.start)} · ${booking.plate}',
                    style: const TextStyle(color: T.muted),
                  ),
                ],
              ),
            ),
            Text(
              _money(booking.totalCents),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        width: 230,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            Text(label, style: const TextStyle(color: T.muted)),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
        ),
        child: Column(
          children: [
            const Icon(Icons.add_home_work_outlined, size: 62, color: T.muted),
            const SizedBox(height: 12),
            const Text(
              'Noch kein Stellplatz',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const Text(
              'Der Einrichtungsassistent führt dich durch Adresse, Maße, Ausstattung und Preis.',
              textAlign: TextAlign.center,
              style: TextStyle(color: T.muted),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Ersten Stellplatz hinzufügen'),
            ),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            TextButton(onPressed: onRetry, child: const Text('Erneut versuchen')),
          ],
        ),
      );
}

String _money(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
