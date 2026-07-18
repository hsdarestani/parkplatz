import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/freiraum_motion.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../host/data/host_repository.dart';
import '../../parking/data/providers.dart';
import '../data/repositories.dart';
import 'booking_screens.dart' as legacy;
import 'booking_ui_components.dart';

class PremiumCheckoutScreen extends ConsumerStatefulWidget {
  const PremiumCheckoutScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<PremiumCheckoutScreen> createState() =>
      _PremiumCheckoutScreenState();
}

class _PremiumCheckoutScreenState extends ConsumerState<PremiumCheckoutScreen> {
  List<VehicleRecord>? vehicles;
  String? selectedVehicleId;
  String? error;
  bool busy = false;
  bool? owner;

  final vehicleName = TextEditingController();
  final plate = TextEditingController();
  final height = TextEditingController();
  final width = TextEditingController();
  final length = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    for (final controller in [
      vehicleName,
      plate,
      height,
      width,
      length,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final results = await Future.wait<dynamic>([
        ref.read(vehicleRepositoryProvider).all(),
        _ownsSpace(),
      ]);
      final loadedVehicles = results[0] as List<VehicleRecord>;
      if (!mounted) return;
      setState(() {
        vehicles = loadedVehicles;
        selectedVehicleId = loadedVehicles
                .where((vehicle) => vehicle.isDefault)
                .firstOrNull
                ?.id ??
            loadedVehicles.firstOrNull?.id;
        owner = results[1] as bool;
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  Future<bool> _ownsSpace() async {
    final auth = ref.read(authRepositoryProvider);
    if (!auth.authenticated && !await auth.restore()) return false;
    final spaces = await ref.read(hostRepositoryProvider).spaces();
    return spaces.any((space) => space.id == widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final spaceState = ref.watch(parkingSpaceProvider(widget.id));
    return FreiraumScaffold(
      title: 'Reservierung prüfen',
      subtitle: 'Zeitraum, Fahrzeug und Preis vor der Bestätigung.',
      activePath: '/discover',
      child: spaceState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => PremiumRetryState(
          message: 'Stellplatz konnte nicht geladen werden.',
          onRetry: () => ref.invalidate(parkingSpaceProvider(widget.id)),
        ),
        data: (space) => space == null
            ? const Center(child: Text('Stellplatz nicht gefunden.'))
            : _content(space),
      ),
    );
  }

  Widget _content(ParkingSpace space) {
    final selected = vehicles
        ?.where((vehicle) => vehicle.id == selectedVehicleId)
        .firstOrNull;
    final fits = selected != null &&
        selected.height <= space.maxHeight &&
        selected.width <= space.maxWidth &&
        selected.length <= space.maxLength;
    final hours = math.max(
      1,
      legacy.selectedEnd.difference(legacy.selectedStart).inHours,
    );
    final totalCents = (space.hourlyPrice * 100 * hours).round();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              children: [
                MotionReveal(child: _CheckoutProgress(owner: owner == true)),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = constraints.maxWidth >= 820;
                    final vehicleCard = MotionReveal(
                      delay: const Duration(milliseconds: 80),
                      child: _vehicleCard(space, selected, fits),
                    );
                    final summary = MotionReveal(
                      delay: const Duration(milliseconds: 140),
                      child: _CheckoutSummary(
                        space: space,
                        totalCents: totalCents,
                        owner: owner == true,
                        checkingOwner: owner == null,
                        busy: busy,
                        fits: fits,
                        error: error,
                        onManage: () => context.go('/host'),
                        onConfirm: selected == null
                            ? null
                            : () => _confirm(space, selected, totalCents),
                      ),
                    );
                    if (!desktop) {
                      return Column(
                        children: [
                          vehicleCard,
                          const SizedBox(height: 18),
                          summary,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: vehicleCard),
                        const SizedBox(width: 20),
                        Expanded(flex: 5, child: summary),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _vehicleCard(
    ParkingSpace space,
    VehicleRecord? selected,
    bool fits,
  ) =>
      BookingSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BookingSectionTitle(
              icon: Icons.directions_car_outlined,
              title: 'Fahrzeug auswählen',
              subtitle: 'Die hinterlegten Maße werden automatisch geprüft.',
            ),
            const SizedBox(height: 18),
            if (vehicles == null) const LinearProgressIndicator(),
            if (vehicles?.isEmpty ?? false)
              const Text(
                'Lege zuerst ein Fahrzeug mit vollständigen Maßen an.',
              ),
            if (vehicles?.isNotEmpty ?? false)
              DropdownButtonFormField<String>(
                value: selectedVehicleId,
                items: vehicles!
                    .map(
                      (vehicle) => DropdownMenuItem(
                        value: vehicle.id,
                        child: Text('${vehicle.name} · ${vehicle.plate}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => selectedVehicleId = value),
                decoration: const InputDecoration(
                  labelText: 'Fahrzeug',
                  prefixIcon: Icon(Icons.directions_car),
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _showAddVehicle,
              icon: const Icon(Icons.add),
              label: const Text('Fahrzeug hinzufügen'),
            ),
            if (selected != null) ...[
              const SizedBox(height: 16),
              _VehicleFitCard(vehicle: selected, fits: fits, space: space),
            ],
          ],
        ),
      );

  Future<void> _showAddVehicle() async {
    vehicleName.clear();
    plate.clear();
    height.clear();
    width.clear();
    length.clear();
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Fahrzeug hinzufügen'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: vehicleName,
                    decoration: const InputDecoration(labelText: 'Bezeichnung'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: plate,
                    decoration: const InputDecoration(labelText: 'Kennzeichen'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _dimensionField(height, 'Höhe')),
                      const SizedBox(width: 10),
                      Expanded(child: _dimensionField(width, 'Breite')),
                      const SizedBox(width: 10),
                      Expanded(child: _dimensionField(length, 'Länge')),
                    ],
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                final dimensions = [height, width, length]
                    .map(
                      (controller) => double.tryParse(
                        controller.text.replaceAll(',', '.'),
                      ),
                    )
                    .toList();
                if (vehicleName.text.trim().isEmpty ||
                    plate.text.trim().isEmpty ||
                    dimensions.any((value) => value == null || value <= 0)) {
                  setDialogState(() {
                    dialogError =
                        'Bitte gib Bezeichnung, Kennzeichen und alle Maße an.';
                  });
                  return;
                }
                final saved = await ref.read(vehicleRepositoryProvider).save(
                      VehicleRecord(
                        id: '',
                        name: vehicleName.text.trim(),
                        plate: plate.text.trim().toUpperCase(),
                        height: dimensions[0]!,
                        width: dimensions[1]!,
                        length: dimensions[2]!,
                        isDefault: vehicles?.isEmpty ?? true,
                      ),
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _bootstrap();
                if (mounted) setState(() => selectedVehicleId = saved.id);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dimensionField(
    TextEditingController controller,
    String label,
  ) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: '$label m'),
      );

  Future<void> _confirm(
    ParkingSpace space,
    VehicleRecord vehicle,
    int totalCents,
  ) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final availability = await ref.read(availabilityRepositoryProvider).check(
            space.id,
            legacy.selectedStart,
            legacy.selectedEnd,
          );
      if (!availability.available) {
        throw ApiConflictException(
          availability.message ?? 'Der Zeitraum ist nicht verfügbar.',
        );
      }
      final seed = DateTime.now().microsecondsSinceEpoch.toString();
      final created = await ref.read(bookingRepositoryProvider).create(
            BookingRecord(
              id: seed,
              parkingId: space.id,
              title: space.title,
              reference: 'FR-${seed.substring(seed.length - 6)}',
              vehicleId: vehicle.id,
              plate: vehicle.plate,
              status: 'confirmed',
              start: legacy.selectedStart,
              end: legacy.selectedEnd,
              hourlyPriceCents: (space.hourlyPrice * 100).round(),
              totalCents: totalCents,
            ),
          );
      if (mounted) context.go('/booking/${created.id}/confirmed');
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _CheckoutProgress extends StatelessWidget {
  const _CheckoutProgress({required this.owner});

  final bool owner;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: owner ? T.amberSoft : T.mintSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: owner ? T.amber : T.mint),
        ),
        child: Row(
          children: [
            Icon(
              owner ? Icons.info_outline : Icons.shield_outlined,
              color: owner ? T.warning : T.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                owner
                    ? 'Eigene Stellplätze können nur verwaltet und nicht gebucht werden.'
                    : 'Deine Buchung wird live geprüft und serverseitig bestätigt.',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
}

class _VehicleFitCard extends StatelessWidget {
  const _VehicleFitCard({
    required this.vehicle,
    required this.fits,
    required this.space,
  });

  final VehicleRecord vehicle;
  final bool fits;
  final ParkingSpace space;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: fits ? T.mintSoft : T.amberSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: fits ? T.mint : T.amber),
        ),
        child: Row(
          children: [
            Icon(
              fits ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              color: fits ? T.success : T.warning,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fits ? 'Fahrzeug passt' : 'Fahrzeug passt nicht',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${vehicle.height} × ${vehicle.width} × ${vehicle.length} m · Stellplatz: ${space.dimensions()}',
                    style: const TextStyle(color: T.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({
    required this.space,
    required this.totalCents,
    required this.owner,
    required this.checkingOwner,
    required this.busy,
    required this.fits,
    required this.error,
    required this.onManage,
    required this.onConfirm,
  });

  final ParkingSpace space;
  final int totalCents;
  final bool owner;
  final bool checkingOwner;
  final bool busy;
  final bool fits;
  final String? error;
  final VoidCallback onManage;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) => BookingSurfaceCard(
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(space.title, style: Theme.of(context).textTheme.headlineSmall),
            Text(
              space.approximate(),
              style: const TextStyle(
                color: T.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _SummaryLine(
              icon: Icons.calendar_today_outlined,
              label: 'Datum',
              value: bookingDateOnly(legacy.selectedStart),
            ),
            _SummaryLine(
              icon: Icons.schedule_outlined,
              label: 'Zeitraum',
              value:
                  '${bookingTime(legacy.selectedStart)} – ${bookingTime(legacy.selectedEnd)} Uhr',
            ),
            const _SummaryLine(
              icon: Icons.lock_outline,
              label: 'Adresse',
              value: 'Nach bestätigter Buchung',
            ),
            const Divider(height: 30),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Gesamtpreis',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  bookingMoney(totalCents),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const Text(
              'Live-Reservierung ohne Online-Zahlung',
              textAlign: TextAlign.end,
              style: TextStyle(color: T.warning, fontSize: 12),
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withOpacity(.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: checkingOwner
                  ? null
                  : owner
                      ? onManage
                      : busy || !fits
                          ? null
                          : onConfirm,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      owner
                          ? Icons.settings_outlined
                          : Icons.lock_open_outlined,
                    ),
              label: Text(
                checkingOwner
                    ? 'Konto wird geprüft …'
                    : owner
                        ? 'Stellplatz verwalten'
                        : busy
                            ? 'Verfügbarkeit wird geprüft …'
                            : 'Reservierung verbindlich bestätigen',
              ),
            ),
          ],
        ),
      );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Row(
          children: [
            Icon(icon, color: T.locked, size: 20),
            const SizedBox(width: 11),
            Expanded(
              child: Text(label, style: const TextStyle(color: T.muted)),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
}
