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
import 'direct_payment_panel.dart';

class DirectPaymentCheckoutScreen extends ConsumerStatefulWidget {
  const DirectPaymentCheckoutScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<DirectPaymentCheckoutScreen> createState() =>
      _DirectPaymentCheckoutScreenState();
}

class _DirectPaymentCheckoutScreenState
    extends ConsumerState<DirectPaymentCheckoutScreen> {
  List<VehicleRecord>? vehicles;
  String? selectedVehicleId;
  String? error;
  bool busy = false;
  bool submitting = false;
  bool? owner;
  PaymentCheckoutResult? checkout;

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
      title: 'Buchung & Direktzahlung',
      subtitle: 'Direkt an den Anbieter zahlen und Zahlung bestätigen lassen.',
      activePath: '/discover',
      child: spaceState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(parkingSpaceProvider(widget.id)),
            icon: const Icon(Icons.refresh),
            label: const Text('Stellplatz erneut laden'),
          ),
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
                    final settings = _settingsCard(space, selected, fits);
                    final summary = _summaryCard(
                      space,
                      selected,
                      fits,
                      estimateCents,
                    );
                    if (!desktop) {
                      return Column(
                        children: [
                          settings,
                          const SizedBox(height: 18),
                          summary,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: settings),
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
              owner == true ? Icons.info_outline : Icons.swap_horiz_rounded,
              color: owner == true ? T.warning : T.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                owner == true
                    ? 'Eigene Stellplätze können verwaltet, aber nicht selbst gebucht werden.'
                    : 'Das Geld geht direkt an den Anbieter. FREIRAUM hält oder verarbeitet keine Kundengelder.',
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
              subtitle: 'Der verbindliche Preis wird serverseitig berechnet.',
            ),
            const SizedBox(height: 18),
            PremiumBookingTimeSelector(
              onChanged: () => setState(() => checkout = null),
            ),
            const SizedBox(height: 24),
            const BookingSectionTitle(
              icon: Icons.directions_car_outlined,
              title: 'Fahrzeug',
              subtitle: 'Die Maße werden vor der Buchungsanfrage geprüft.',
            ),
            const SizedBox(height: 18),
            if (vehicles == null) const LinearProgressIndicator(),
            if (vehicles?.isEmpty ?? false) ...[
              const Text('Für die Buchung brauchst du ein Fahrzeug.'),
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
                onChanged: (value) => setState(() {
                  selectedVehicleId = value;
                  checkout = null;
                }),
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
                child: Text(
                  fits
                      ? '${selected.name} passt in diesen Stellplatz.'
                      : '${selected.name} überschreitet die zulässigen Maße.',
                  style: const TextStyle(fontWeight: FontWeight.w900),
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
            Text(space.approximate(), style: const TextStyle(color: T.muted)),
            const SizedBox(height: 20),
            _line('Datum', legacy.selectedStart.toLocal().toString().split(' ').first),
            _line(
              'Zeitraum',
              '${legacy.selectedStart.hour.toString().padLeft(2, '0')}:${legacy.selectedStart.minute.toString().padLeft(2, '0')} – ${legacy.selectedEnd.hour.toString().padLeft(2, '0')}:${legacy.selectedEnd.minute.toString().padLeft(2, '0')} Uhr',
            ),
            _line('Fahrzeug', selected?.plate ?? 'Noch nicht gewählt'),
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
                  _money(estimateCents),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (checkout?.directPayment != null)
              DirectPaymentPanel(
                value: checkout!.directPayment!,
                busy: submitting,
                onSubmit: _submitReference,
              )
            else ...[
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
                    : () => _createRequest(space, selected, estimateCents),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        owner == true
                            ? Icons.settings_outlined
                            : Icons.arrow_forward_rounded,
                      ),
                label: Text(
                  owner == true
                      ? 'Stellplatz verwalten'
                      : busy
                          ? 'Buchungsanfrage wird erstellt …'
                          : 'Direktzahlung vorbereiten',
                ),
              ),
              if (owner != true) ...[
                const SizedBox(height: 9),
                const Text(
                  'Adresse und Parking Pass werden nach Bestätigung durch den Anbieter freigeschaltet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: T.muted, fontSize: 12),
                ),
              ],
            ],
          ],
        ),
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
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

  Future<void> _createRequest(
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
      if (result.directPayment != null) {
        if (mounted) setState(() => checkout = result);
        return;
      }
      if (result.requiresRedirect && result.checkoutUrl != null) {
        await launchUrl(
          Uri.parse(result.checkoutUrl!),
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_self',
        );
        return;
      }
      if (mounted) context.go('/booking/${result.bookingId}/confirmed');
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submitReference(String reference) async {
    final result = checkout;
    if (result == null) return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await ref
          .read(paymentRepositoryProvider)
          .submitDirectReference(result.bookingId, reference);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zahlung wurde zur Bestätigung eingereicht.'),
        ),
      );
      context.go('/bookings');
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }
}

String _money(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';
