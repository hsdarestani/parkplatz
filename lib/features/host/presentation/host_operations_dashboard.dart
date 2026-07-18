import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_motion.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../booking/data/repositories.dart';
import '../data/host_repository.dart';
import 'host_dashboard_widgets.dart';
import 'host_manage_components.dart';

class HostOperationsDashboard extends ConsumerStatefulWidget {
  const HostOperationsDashboard({super.key});

  @override
  ConsumerState<HostOperationsDashboard> createState() =>
      _HostOperationsDashboardState();
}

class _HostOperationsDashboardState
    extends ConsumerState<HostOperationsDashboard> {
  late Future<_Snapshot> future = _load();

  Future<_Snapshot> _load() async {
    final repository = ref.read(hostRepositoryProvider);
    return _Snapshot(
      await repository.spaces(),
      await repository.bookings(),
    );
  }

  void _reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Stellplatz vermieten',
        subtitle: 'Angebote, Buchungen, Preise und Verfügbarkeit verwalten.',
        activePath: '/host',
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/host/new'),
            icon: const Icon(Icons.add),
            label: const Text('Stellplatz hinzufügen'),
          ),
        ],
        child: FutureBuilder<_Snapshot>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return HostErrorState(
                message: snapshot.error.toString(),
                onRetry: _reload,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _content(snapshot.data!);
          },
        ),
      );

  Widget _content(_Snapshot snapshot) {
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
        _reload();
        await future;
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MotionReveal(child: _hero()),
                  const SizedBox(height: 18),
                  MotionReveal(
                    delay: const Duration(milliseconds: 70),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        HostMetricCard(
                          '$active',
                          'aktive Stellplätze',
                          icon: Icons.local_parking_outlined,
                        ),
                        HostMetricCard(
                          '${confirmed.length}',
                          'offene Buchungen',
                          icon: Icons.event_available_outlined,
                        ),
                        HostMetricCard(
                          '${euros(earnings)} €',
                          'Beta-Umsatz',
                          icon: Icons.payments_outlined,
                        ),
                      ],
                    ),
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
                    HostEmptySpaces(onAdd: () => context.go('/host/new'))
                  else
                    ...snapshot.spaces.map(
                      (space) => HostSpaceCard(
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
                    ...snapshot.bookings.take(5).map(HostBookingTile.new),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [T.ink, T.inkSoft]),
          borderRadius: BorderRadius.circular(T.radiusSpacious),
          boxShadow: T.shadow,
        ),
        child: Wrap(
          spacing: 24,
          runSpacing: 18,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(
              Icons.dashboard_customize_outlined,
              color: T.mint,
              size: 54,
            ),
            const SizedBox(
              width: 620,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dein Vermietungs-Cockpit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Bearbeite Angebote, steuere Wochenpläne, Sperrzeiten und dynamische Preise.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/host/new'),
              icon: const Icon(Icons.add),
              label: const Text('Neuen Stellplatz anlegen'),
            ),
          ],
        ),
      );

  Future<void> _setStatus(HostSpaceRecord space, String status) async {
    try {
      await ref.read(hostRepositoryProvider).setStatus(space.id, status);
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}

class _Snapshot {
  const _Snapshot(this.spaces, this.bookings);

  final List<HostSpaceRecord> spaces;
  final List<BookingRecord> bookings;
}
