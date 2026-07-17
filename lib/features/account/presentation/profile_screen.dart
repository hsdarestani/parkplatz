import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../booking/data/repositories.dart';
import '../../host/data/host_repository.dart';
import '../../parking/data/providers.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<_Snapshot> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<_Snapshot> _load() async {
    final auth = ref.read(authRepositoryProvider);
    if (!auth.authenticated && !await auth.restore()) {
      throw const ApiUnauthorizedException();
    }
    final user = await ref.read(profileRepositoryProvider).read();
    final vehicles = await ref.read(vehicleRepositoryProvider).all();
    final bookings = await ref.read(bookingRepositoryProvider).all();
    final spaces = await ref.read(hostRepositoryProvider).spaces();
    return _Snapshot(user, vehicles, bookings, spaces);
  }

  void reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Profil',
        subtitle: 'Konto, Fahrzeuge und Vermietung an einem Ort.',
        activePath: '/profile',
        actions: [
          IconButton(
            tooltip: 'Abmelden',
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
        child: FutureBuilder<_Snapshot>(
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

  Widget _content(_Snapshot snapshot) {
    final activeBookings = snapshot.bookings
        .where((booking) => booking.status == 'confirmed')
        .length;
    final activeSpaces = snapshot.spaces.where((space) => space.active).length;
    final initial = snapshot.user.displayName.trim().isEmpty
        ? 'F'
        : snapshot.user.displayName.trim()[0].toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [T.ink, T.inkSoft],
                  ),
                  borderRadius: BorderRadius.circular(T.radiusSpacious),
                  boxShadow: T.shadow,
                ),
                child: Wrap(
                  spacing: 22,
                  runSpacing: 18,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: T.mint,
                      foregroundColor: T.ink,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 430,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snapshot.user.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            snapshot.user.email,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '● Live-Konto',
                            style: TextStyle(
                              color: T.mint,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _editName(snapshot.user),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Name bearbeiten'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _Metric(
                    value: '$activeBookings',
                    label: 'aktive Buchungen',
                    icon: Icons.confirmation_number_outlined,
                  ),
                  _Metric(
                    value: '${snapshot.vehicles.length}',
                    label: 'Fahrzeuge',
                    icon: Icons.directions_car_outlined,
                  ),
                  _Metric(
                    value: '$activeSpaces',
                    label: 'aktive Stellplätze',
                    icon: Icons.add_home_work_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Schnellzugriff',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.calendar_month_outlined,
                title: 'Meine Buchungen',
                subtitle: 'Reservierungen und Parking Pass verwalten',
                onTap: () => context.go('/bookings'),
              ),
              _ActionTile(
                icon: Icons.directions_car_filled_outlined,
                title: 'Meine Fahrzeuge',
                subtitle: 'Kennzeichen und Fahrzeugmaße verwalten',
                onTap: () => context.go('/vehicles'),
              ),
              _ActionTile(
                icon: Icons.add_home_work_outlined,
                title: 'Stellplatz vermieten',
                subtitle: 'Neuen Stellplatz hinzufügen oder pausieren',
                highlighted: true,
                onTap: () => context.go('/host'),
              ),
              _ActionTile(
                icon: Icons.shield_outlined,
                title: 'Datenschutz',
                subtitle: 'Genaue Adressen bleiben bis zur Buchung geschützt',
                onTap: () => _info(
                  'Datenschutz',
                  'Die genaue Stellplatzadresse und Zufahrt werden nur nach einer bestätigten Buchung freigegeben.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editName(AppUser user) async {
    final controller = TextEditingController(text: user.displayName);
    final changed = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Profilname bearbeiten'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 2) Navigator.pop(dialogContext, value);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (changed == null) return;
    try {
      await ref.read(profileRepositoryProvider).updateDisplayName(changed);
      reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _info(String title, String text) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Verstanden'),
            ),
          ],
        ),
      );
}

class _Snapshot {
  const _Snapshot(this.user, this.vehicles, this.bookings, this.spaces);

  final AppUser user;
  final List<VehicleRecord> vehicles;
  final List<BookingRecord> bookings;
  final List<HostSpaceRecord> spaces;
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 245,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
          boxShadow: T.shadowSmall,
        ),
        child: Row(
          children: [
            Icon(icon, color: T.success),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(label, style: const TextStyle(color: T.muted)),
              ],
            ),
          ],
        ),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: highlighted ? T.mintSoft : T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(T.radius),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(T.radius),
                border: Border.all(
                  color: highlighted ? T.mint : T.line,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: highlighted ? T.success : T.ink),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(subtitle, style: const TextStyle(color: T.muted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
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
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      );
}
