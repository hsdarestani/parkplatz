import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/design_tokens.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/freiraum_motion.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../booking/data/repositories.dart';
import '../../booking/presentation/booking_screens.dart' as legacy;
import '../../booking/presentation/booking_ui_components.dart';
import '../../host/data/host_repository.dart';
import '../../parking/data/providers.dart';
import '../data/payment_repository.dart';

class PaymentCheckoutScreen extends ConsumerStatefulWidget {
  const PaymentCheckoutScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<PaymentCheckoutScreen> createState() =>
      _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends ConsumerState<PaymentCheckoutScreen> {
  List<VehicleRecord>? vehicles;
  String? selectedVehicleId;
  String? error;
  bool busy = false;
  bool? owner;

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    try {
      final results = await Future.wait<dynamic>([
        ref.read(vehicleRepositoryProvider).all(),
        ref.read(hostRepositoryProvider).spaces(),
      ]);
      final loadedVehicles = results[0] as List<VehicleRecord>;
      final ownedSpaces = results[1] as List<HostSpaceRecord>;
      if (!mounted) return;
      setState(() {
        vehicles = loadedVehicles;
        selectedVehicleId = loadedVehicles
                .where((vehicle) => vehicle.isDefault)
                .firstOrNull
                ?.id ??
            loadedVehicles.firstOrNull?.id;
        owner = ownedSpaces.any((space) => space.id == widget.id);
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final spaceState = ref.watch(parkingSpaceProvider(widget.id));
    return FreiraumScaffold(
      title: 'Sicher bezahlen',
      subtitle: 'Zeitraum, Fahrzeug und Zahlung verbindlich prüfen.',
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
    final estimateCents = (space.hourlyPrice * 100 * hours).round();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              children: [
                MotionReveal(child: _trustBanner()),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = constraints.maxWidth >= 840;
                    final settingsCard = MotionReveal(
                      delay: const Duration(milliseconds: 80),
                      child: _settingsCard(space, selected, fits),
                    );
                    final summaryCard = MotionReveal(
                      delay: const Duration(milliseconds: 140),
                      child: _summaryCard(
                        space,
                        selected,
                        fits,
                        estimateCents,
                      ),
                    );
                    if (!desktop) {
                      return Column(
                        children: [
                          settingsCard,
                          const SizedBox(height: 18),
                          summaryCard,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: settingsCard),
                        const SizedBox(width: 20),
                        Expanded(flex: 5, child: summaryCard),
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

  Widget _trustBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: owner == true ? T.amberSoft : T.mintSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: owner == true ? T.amber : T.mint),
        ),
        child: Row(
          children: [
            Icon(
              owner == true ? Icons.info_outline : Icons.verified_user_outlined,
              color: owner == true ? T.warning : T.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                owner == true
                    ? 'Eigene Stellplätze können verwaltet, aber nicht selbst gebucht werden.'
                    : 'Der Zeitraum wird während der Zahlung reserviert. Die Buchung wird erst nach erfolgreicher Zahlung bestätigt.',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );

  Widget _settingsCard(
    ParkingSpace space,
    VehicleRecord? selected,
    bool fits,
  ) =>
      BookingSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BookingSectionTitle(
              icon: Icons.calendar_month_outlined,
              title: 'Zeitraum',
              subtitle: 'Der Preis wird serverseitig mit dem Tagespreis berechnet.',
            ),
            const SizedBox(height: 18),
            PremiumBookingTimeSelector(onChanged: () => setState(() {})),
            const SizedBox(height: 24),
            const BookingSectionTitle(
              icon: Icons.directions_car_outlined,
              title: 'Fahrzeug',
              subtitle: 'Die Maße werden vor dem Bezahlen geprüft.',
            ),
            const SizedBox(height: 18),
            if (vehicles == null) const LinearProgressIndicator(),
            if (vehicles?.isEmpty ?? false) ...[
              const Text(
                'Für die Buchung brauchst du ein Fahrzeug mit vollständigen Maßen.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/vehicles'),
                icon: const Icon(Icons.add),
                label: const Text('Fahrzeug anlegen'),
              ),
            ],
            if (vehicles?.isNotEmpty ?? false)
              DropdownButtonFormField<String>(
                value: selectedVehicleId,
                decoration: const InputDecoration(
                  labelText: 'Fahrzeug auswählen',
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: vehicles!
                    .map(
                      (vehicle) => DropdownMenuItem(
                        value: vehicle.id,
                        child: Text('${vehicle.name} · ${vehicle.plate}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => selectedVehicleId = value),
              ),
            if (selected != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: fits ? T.mintSoft : T.amberSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: fits ? T.mint : T.amber),
                ),
                child: Row(
                  children: [
                    Icon(
                      fits
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                      color: fits ? T.success : T.warning,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        fits
                            ? '${selected.name} passt in diesen Stellplatz.'
                            : '${selected.name} überschreitet die zulässigen Maße.',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  Widget _summaryCard(
    ParkingSpace space,
    VehicleRecord? selected,
    bool fits,
    int estimateCents,
  ) =>
      BookingSurfaceCard(
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
            _line(
              Icons.calendar_today_outlined,
              'Datum',
              bookingDateOnly(legacy.selectedStart),
            ),
            _line(
              Icons.schedule_outlined,
              'Zeitraum',
              '${bookingTime(legacy.selectedStart)} – ${bookingTime(legacy.selectedEnd)} Uhr',
            ),
            _line(
              Icons.directions_car_outlined,
              'Fahrzeug',
              selected?.plate ?? 'Noch nicht gewählt',
            ),
            const Divider(height: 30),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Voraussichtlicher Preis',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  bookingMoney(estimateCents),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const Text(
              'Der verbindliche Betrag erscheint auf der Zahlungsseite.',
              textAlign: TextAlign.end,
              style: TextStyle(color: T.muted, fontSize: 12),
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
              onPressed: owner == true ||
                      owner == null ||
                      busy ||
                      selected == null ||
                      !fits
                  ? owner == true
                      ? () => context.go('/host/${space.id}/manage')
                      : null
                  : () => _pay(space, selected, estimateCents),
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
                      owner == true
                          ? Icons.settings_outlined
                          : Icons.lock_outline,
                    ),
              label: Text(
                owner == true
                    ? 'Stellplatz verwalten'
                    : busy
                        ? 'Zahlung wird vorbereitet …'
                        : 'Weiter zur sicheren Zahlung',
              ),
            ),
            if (owner != true) ...[
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, color: T.success, size: 17),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Verschlüsselte Zahlung · Adresse erst nach Bestätigung',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: T.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );

  Widget _line(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Row(
          children: [
            Icon(icon, color: T.locked, size: 20),
            const SizedBox(width: 11),
            Expanded(child: Text(label, style: const TextStyle(color: T.muted))),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );

  Future<void> _pay(
    ParkingSpace space,
    VehicleRecord vehicle,
    int estimateCents,
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
      final result = await ref.read(paymentRepositoryProvider).createCheckout(
            BookingRecord(
              id: seed,
              parkingId: space.id,
              title: space.title,
              reference: 'FR-${seed.substring(seed.length - 6)}',
              vehicleId: vehicle.id,
              plate: vehicle.plate,
              status: 'pending',
              start: legacy.selectedStart,
              end: legacy.selectedEnd,
              hourlyPriceCents: (space.hourlyPrice * 100).round(),
              totalCents: estimateCents,
            ),
          );

      if (!result.requiresRedirect) {
        if (mounted) context.go('/booking/${result.bookingId}/confirmed');
        return;
      }

      final checkoutUrl = result.checkoutUrl;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw const ApiServerException();
      }
      final opened = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );
      if (!opened) {
        throw const ApiOfflineException();
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
