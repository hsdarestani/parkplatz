import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../booking/data/repositories.dart';
import '../../booking/presentation/booking_ui_components.dart';
import '../../host/data/host_repository.dart';
import '../../parking/data/providers.dart';
import '../../search/presentation/search_controller.dart';
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
    final space = ref.watch(parkingSpaceProvider(widget.id));
    return FreiraumScaffold(
      title: 'Buchung prüfen',
      subtitle: 'Zeitraum, Fahrzeug und Bestätigung kontrollieren.',
      activePath: '/discover',
      child: space.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(parkingSpaceProvider(widget.id)),
            icon: const Icon(Icons.refresh),
            label: const Text('Stellplatz erneut laden'),
          ),
        ),
        data: (value) => value == null
            ? const Center(child: Text('Stellplatz nicht gefunden.'))
            : _content(value),
      ),
    );
  }

  Widget _content(ParkingSpace space) {
    final query = ref.watch(searchProvider);
    final selected = vehicles
        ?.where((vehicle) => vehicle.id == selectedVehicleId)
        .firstOrNull;
    final fits = selected != null &&
        selected.height <= space.maxHeight &&
        selected.width <= space.maxWidth &&
        selected.length <= space.maxLength;
    final estimateCents = (space.hourlyPrice * 100 * query.hours).round();
    final compact = MediaQuery.sizeOf(context).width < 620;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 24,
        compact ? 14 : 24,
        compact ? 14 : 24,
        MediaQuery.paddingOf(context).bottom + 90,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              children: [
                _trustBanner(space),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final settings = _settingsCard(space, selected, fits);
                    final summary = _summaryCard(
                      space,
                      selected,
                      fits,
                      estimateCents,
                    );
                    if (constraints.maxWidth < 840) {
                      return Column(
                        children: [settings, const SizedBox(height: 18), summary],
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

  Widget _trustBanner(ParkingSpace space) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: owner == true ? T.amberSoft : T.mintSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: owner == true ? T.amber : T.mint),
        ),
        child: Row(
          children: [
            Icon(
              owner == true
                  ? Icons.info_outline
                  : space.free
                      ? Icons.volunteer_activism_outlined
                      : Icons.swap_horiz_rounded,
              color: owner == true ? T.warning : T.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                owner == true
                    ? 'Eigene Stellplätze können nicht selbst gebucht werden.'
                    : space.free
                        ? 'Dieser Stellplatz ist kostenlos. Der Anbieter bestätigt die Anfrage trotzdem.'
                        : 'Du zahlst direkt an den Anbieter. Erst danach bestätigt er die Buchung.',
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
              subtitle: 'Nur ein wirklich freier Zeitraum kann angefragt werden.',
            ),
            const SizedBox(height: 18),
            PremiumBookingTimeSelector(
              onChanged: () => setState(() => checkout = null),
            ),
            const SizedBox(height: 24),
            const BookingSectionTitle(
              icon: Icons.directions_car_outlined,
              title: 'Fahrzeug',
              subtitle: 'Eigenes Fahrzeug auswählen oder direkt hinzufügen.',
            ),
            const SizedBox(height: 18),
            if (vehicles == null) const LinearProgressIndicator(),
            if (vehicles?.isNotEmpty ?? false)
              DropdownButtonFormField<String>(
                value: selectedVehicleId,
                decoration: const InputDecoration(
                  labelText: 'Fahrzeug auswählen',
                  prefixIcon: Icon(Icons.directions_car_rounded),
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
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => context.push('/vehicles').then((_) => _loadAccountData()),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                vehicles?.isEmpty ?? true
                    ? 'Fahrzeug anlegen'
                    : 'Weiteres Fahrzeug hinzufügen',
              ),
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
                      fits ? Icons.check_circle_outline : Icons.straighten,
                      color: fits ? T.success : T.warning,
                    ),
                    const SizedBox(width: 10),
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
  ) {
    final query = ref.watch(searchProvider);
    return BookingSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(space.title, style: Theme.of(context).textTheme.headlineSmall),
          Text(space.approximate(), style: const TextStyle(color: T.muted)),
          const SizedBox(height: 20),
          _line(
            Icons.calendar_today_outlined,
            'Datum',
            bookingDateOnly(query.start),
          ),
          _line(
            Icons.schedule_outlined,
            'Zeitraum',
            '${bookingTime(query.start)} – ${bookingTime(query.end)} Uhr',
          ),
          _line(
            Icons.timelapse_outlined,
            'Dauer',
            '${query.hours} ${query.hours == 1 ? 'Stunde' : 'Stunden'}',
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
                  'Gesamtpreis',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                space.free ? 'Kostenlos' : bookingMoney(estimateCents),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: space.free ? T.success : T.ink,
                ),
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
              onUploadReceipt: _uploadReceipt,
            )
          else if (checkout?.status == 'awaiting_host_confirmation') ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: T.mintSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: T.mint),
              ),
              child: const Column(
                children: [
                  Icon(Icons.mark_email_read_outlined, color: T.success, size: 38),
                  SizedBox(height: 8),
                  Text(
                    'Anfrage wurde an den Anbieter gesendet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Adresse und Parking Pass werden nach seiner Bestätigung freigeschaltet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: T.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => context.go('/bookings'),
              icon: const Icon(Icons.confirmation_number_outlined),
              label: const Text('Meine Buchungen öffnen'),
            ),
          ] else ...[
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
                          : space.free
                              ? Icons.send_outlined
                              : Icons.arrow_forward_rounded,
                    ),
              label: Text(
                owner == true
                    ? 'Stellplatz verwalten'
                    : busy
                        ? 'Anfrage wird erstellt …'
                        : space.free
                            ? 'Kostenlose Anfrage senden'
                            : 'Direktzahlung vorbereiten',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: T.muted),
            const SizedBox(width: 8),
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
    final query = ref.read(searchProvider);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final availability = await ref.read(availabilityRepositoryProvider).check(
            space.id,
            query.start,
            query.end,
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
              start: query.start,
              end: query.end,
              hourlyPriceCents: (space.hourlyPrice * 100).round(),
              totalCents: estimateCents,
            ),
          );
      if (mounted) setState(() => checkout = result);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submitReference(String reference) async {
    final value = checkout;
    if (value == null) return;
    setState(() => submitting = true);
    try {
      await ref
          .read(paymentRepositoryProvider)
          .submitDirectReference(value.bookingId, reference);
      if (mounted) context.go('/bookings');
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<ReceiptUpload> _uploadReceipt(
    Uint8List bytes,
    String filename,
  ) async {
    final value = checkout;
    if (value == null) throw StateError('Buchung fehlt.');
    return ref
        .read(paymentRepositoryProvider)
        .uploadReceipt(value.bookingId, bytes, filename);
  }
}
