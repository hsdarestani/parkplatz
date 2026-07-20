import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../booking/data/repositories.dart';
import '../../host/data/host_repository.dart';
import '../../marketplace/data/marketplace_repository.dart';
import '../../parking/data/providers.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<_Snapshot> future;
  bool uploadingPhoto = false;

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
            onPressed: _logout,
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
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [T.ink, T.inkSoft]),
                  borderRadius: BorderRadius.circular(T.radiusSpacious),
                  boxShadow: T.shadow,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 650;
                    final avatar = Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: T.mint,
                          foregroundColor: T.ink,
                          backgroundImage: snapshot.user.profileImageUrl == null
                              ? null
                              : NetworkImage(snapshot.user.profileImageUrl!),
                          child: snapshot.user.profileImageUrl == null
                              ? Text(
                                  initial,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: -6,
                          bottom: -6,
                          child: IconButton.filled(
                            tooltip: 'Profilbild ändern',
                            onPressed: uploadingPhoto ? null : _pickProfilePhoto,
                            icon: uploadingPhoto
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.photo_camera_outlined),
                          ),
                        ),
                      ],
                    );
                    final identity = Column(
                      crossAxisAlignment: compact
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          snapshot.user.displayName,
                          textAlign: compact ? TextAlign.center : TextAlign.start,
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
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_outlined, color: T.mint, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Live-Konto',
                              style: TextStyle(
                                color: T.mint,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                    final actions = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: compact ? WrapAlignment.center : WrapAlignment.end,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _editName(snapshot.user),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Name bearbeiten'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Abmelden'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                          ),
                        ),
                      ],
                    );
                    if (compact) {
                      return Column(
                        children: [
                          avatar,
                          const SizedBox(height: 18),
                          identity,
                          const SizedBox(height: 18),
                          actions,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        avatar,
                        const SizedBox(width: 24),
                        Expanded(child: identity),
                        actions,
                      ],
                    );
                  },
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
              Text('Schnellzugriff', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.search_rounded,
                title: 'Stellplatz suchen',
                subtitle: 'Datum, Uhrzeit und Fahrzeug auswählen',
                onTap: () => context.go('/discover'),
              ),
              _ActionTile(
                icon: Icons.calendar_month_outlined,
                title: 'Meine Buchungen',
                subtitle: 'Reservierungen, Bewertungen und Parking Pass',
                onTap: () => context.go('/bookings'),
              ),
              _ActionTile(
                icon: Icons.directions_car_filled_outlined,
                title: 'Meine Fahrzeuge',
                subtitle: 'Kennzeichen, Fahrzeugklasse und Maße verwalten',
                onTap: () => context.go('/vehicles'),
              ),
              _ActionTile(
                icon: Icons.add_home_work_outlined,
                title: 'Stellplatz vermieten',
                subtitle: 'Adresse, Pin, Ausstattung und Fotos verwalten',
                highlighted: true,
                onTap: () => context.go('/host'),
              ),
              _ActionTile(
                icon: Icons.bookmark_outline_rounded,
                title: 'Gemerkte Stellplätze',
                subtitle: 'Gespeicherte Favoriten öffnen',
                onTap: () => context.go('/favorites'),
              ),
              _ActionTile(
                icon: Icons.verified_user_outlined,
                title: 'Vertrauen & Kontohilfe',
                subtitle: 'Prüfungen und Anfragen verwalten',
                onTap: () => context.go('/trust'),
              ),
              _ActionTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Datenschutz & Rechtliches',
                subtitle: 'Datenschutz, Bedingungen und Impressum öffnen',
                onTap: () => context.go('/legal/privacy'),
              ),
              _ActionTile(
                icon: Icons.logout_rounded,
                title: 'Abmelden',
                subtitle: 'Aktuelle Sitzung beenden',
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    final file = selection?.files.single;
    if (file?.bytes == null) return;
    setState(() => uploadingPhoto = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .uploadProfileImage(file!.bytes!, file.name);
      reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => uploadingPhoto = false);
    }
  }

  Future<void> _editName(ProfileUser user) async {
    final controller = TextEditingController(text: user.displayName);
    final changed = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Profilname bearbeiten'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          FilledButton.icon(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 2) Navigator.pop(dialogContext, value);
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Speichern'),
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

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).logout();
    if (mounted) context.go('/login');
  }
}

class _Snapshot {
  const _Snapshot(this.user, this.vehicles, this.bookings, this.spaces);

  final ProfileUser user;
  final List<VehicleRecord> vehicles;
  final List<BookingRecord> bookings;
  final List<HostSpaceRecord> spaces;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, required this.icon});

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
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
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
                border: Border.all(color: highlighted ? T.mint : T.line),
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
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      );
}