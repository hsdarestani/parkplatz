import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/models/models.dart';
import '../../parking/data/demo_parking_repository.dart';
import '../data/repositories.dart';

final betaAuth = LocalBetaAuthRepository();
final betaBookings = LocalBetaBookingRepository();

DateTime selectedStart = DateTime.now().add(const Duration(days: 1));
DateTime selectedEnd = DateTime.now().add(const Duration(days: 1, hours: 2));

ParkingSpace _space(String id) => DemoParkingRepository.spaces.firstWhere(
      (parkingSpace) => parkingSpace.id == id,
      orElse: () => DemoParkingRepository.spaces.first,
    );

String _money(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

String _date(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day.$month.${date.year} · $hour:$minute';
}

class BetaScaffold extends StatelessWidget {
  const BetaScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.porcelain,
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: T.amberSoft,
            padding: const EdgeInsets.all(12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                'Lokaler Beta-Modus – Buchungen werden nur auf diesem Gerät gespeichert.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: T.ink,
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class ParkingDetailScreen extends StatefulWidget {
  const ParkingDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<ParkingDetailScreen> createState() => _ParkingDetailState();
}

class _ParkingDetailState extends State<ParkingDetailScreen> {
  bool saved = false;

  @override
  Widget build(BuildContext context) {
    final parkingSpace = _space(widget.id);
    final hours = selectedEnd
        .difference(selectedStart)
        .inHours
        .clamp(1, 24)
        .toInt();
    final totalCents =
        (parkingSpace.hourlyPrice * 100 * hours).round();

    return BetaScaffold(
      title: 'Stellplatz',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [T.inkSoft, T.ink],
                    ),
                    borderRadius: BorderRadius.circular(T.radius),
                  ),
                  child: Center(
                    child: Icon(
                      parkingSpace.covered
                          ? Icons.garage_rounded
                          : Icons.local_parking_rounded,
                      size: 100,
                      color: T.mint,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        parkingSpace.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      tooltip: saved ? 'Nicht mehr merken' : 'Merken',
                      onPressed: () => setState(() => saved = !saved),
                      icon: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_border,
                        color: T.ink,
                      ),
                    ),
                    Text(saved ? 'Gemerkt' : 'Merken'),
                  ],
                ),
                Text(
                  '${parkingSpace.district} · nahe ${parkingSpace.landmark} · '
                  '${parkingSpace.walkingMinutes} Min. zu Fuß',
                  style: const TextStyle(color: T.muted, fontSize: 16),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _tag('✓ Verifiziert'),
                    _tag(
                      '★ ${parkingSpace.rating} '
                      '(${parkingSpace.reviewCount})',
                    ),
                    _tag(parkingSpace.accessLabel()),
                    _tag(
                      parkingSpace.covered
                          ? 'Überdacht'
                          : 'Nicht überdacht',
                    ),
                    if (parkingSpace.ev) _tag('E-Laden'),
                    if (parkingSpace.accessible) _tag('Barrierearm'),
                  ],
                ),
                const SizedBox(height: 24),
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Zeitraum wählen',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      BookingTimeSelector(onChanged: () => setState(() {})),
                      const SizedBox(height: 12),
                      Text(
                        'Verfügbar · ${_money(totalCents)} gesamt',
                        style: const TextStyle(
                          color: T.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parkingSpace.dimensions(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(parkingSpace.cancellationSummary),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.lock_outline, color: T.locked),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Die genaue Adresse und Zufahrt werden nach '
                              'bestätigter Buchung freigeschaltet.',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final checkoutPath = '/checkout/${parkingSpace.id}';
                      if (betaAuth.authenticated) {
                        context.go(checkoutPath);
                      } else {
                        context.go(
                          '/login?returnTo=${Uri.encodeComponent(checkoutPath)}',
                        );
                      }
                    },
                    child: const Text('Jetzt reservieren'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BookingTimeSelector extends StatefulWidget {
  const BookingTimeSelector({super.key, required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<BookingTimeSelector> createState() => _TimeState();
}

class _TimeState extends State<BookingTimeSelector> {
  static const availableHours = [8, 10, 12, 14, 16, 18, 20];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text(_date(selectedStart)),
          onPressed: () async {
            final selectedDate = await showDatePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
              initialDate: selectedStart,
            );
            if (selectedDate == null) {
              return;
            }

            selectedStart = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedStart.hour,
            );
            selectedEnd = selectedStart.add(const Duration(hours: 2));
            widget.onChanged();
            setState(() {});
          },
        ),
        DropdownButton<int>(
          value: selectedStart.hour,
          items: availableHours
              .map(
                (hour) => DropdownMenuItem(
                  value: hour,
                  child: Text('${hour.toString().padLeft(2, '0')}:00 Uhr'),
                ),
              )
              .toList(),
          onChanged: (hour) {
            if (hour == null) {
              return;
            }
            selectedStart = DateTime(
              selectedStart.year,
              selectedStart.month,
              selectedStart.day,
              hour,
            );
            selectedEnd = selectedStart.add(const Duration(hours: 2));
            widget.onChanged();
            setState(() {});
          },
        ),
      ],
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.register,
    this.returnTo,
  });

  final bool register;
  final String? returnTo;

  @override
  State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  bool accepted = false;
  bool hidden = true;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BetaScaffold(
      title: widget.register ? 'Konto erstellen' : 'Anmelden',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.register
                        ? 'Willkommen bei FREIRAUM'
                        : 'Schön, dich wiederzusehen',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (widget.register)
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-Mail'),
                  ),
                  TextField(
                    controller: password,
                    obscureText: hidden,
                    decoration: InputDecoration(
                      labelText: 'Passwort (mindestens 8 Zeichen)',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => hidden = !hidden),
                        icon: Icon(
                          hidden ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  if (widget.register)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: accepted,
                      onChanged: (value) =>
                          setState(() => accepted = value ?? false),
                      title: const Text(
                        'Ich akzeptiere die Beta-Bedingungen.',
                      ),
                    ),
                  const Text(
                    'E-Mail-Verifizierung folgt vor dem öffentlichen Start.',
                    style: TextStyle(color: T.muted),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: Text(
                      busy
                          ? 'Bitte warten …'
                          : widget.register
                              ? 'Registrieren'
                              : 'Anmelden',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final path = widget.register ? '/login' : '/register';
                      final returnTo = widget.returnTo;
                      context.go(
                        returnTo == null
                            ? path
                            : '$path?returnTo=${Uri.encodeComponent(returnTo)}',
                      );
                    },
                    child: Text(
                      widget.register
                          ? 'Bereits registriert? Anmelden'
                          : 'Noch kein Konto? Registrieren',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (widget.register && !accepted) {
      setState(() {
        error = 'Bitte akzeptiere die Beta-Bedingungen.';
      });
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      if (widget.register) {
        await betaAuth.register(name.text, email.text, password.text);
      } else {
        await betaAuth.login(email.text, password.text);
      }
      if (mounted) {
        context.go(widget.returnTo ?? '/bookings');
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = exception is FormatException
              ? exception.message.toString()
              : 'Anmeldung nicht möglich.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.id});

  final String id;

  @override
  State<CheckoutScreen> createState() => _CheckoutState();
}

class _CheckoutState extends State<CheckoutScreen> {
  final plate = TextEditingController(text: 'F-RA 2026');

  bool busy = false;
  String? error;

  @override
  void dispose() {
    plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parkingSpace = _space(widget.id);
    final hours = selectedEnd
        .difference(selectedStart)
        .inHours
        .clamp(1, 24)
        .toInt();
    final totalCents =
        (parkingSpace.hourlyPrice * 100 * hours).round();

    return BetaScaffold(
      title: 'Reservierung prüfen',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Beta-Reservierung ohne Online-Zahlung',
                        style: TextStyle(
                          color: T.warning,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        parkingSpace.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(parkingSpace.approximate()),
                      const Divider(height: 32),
                      Text(
                        '${_date(selectedStart)} – '
                        '${selectedEnd.hour.toString().padLeft(2, '0')}:00 Uhr',
                      ),
                      Text(
                        '$hours Stunden · '
                        '${parkingSpace.hourlyPrice.toStringAsFixed(2).replaceAll('.', ',')} '
                        '€/Std.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: plate,
                        decoration: const InputDecoration(
                          labelText: 'Kennzeichen',
                          helperText: (
                            'Fahrzeugmaße werden vor der Reservierung geprüft.'
                          ),
                        ),
                      ),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Gesamt',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            _money(totalCents),
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Keine Online-Zahlung · flexibel bis 1 Stunde vorher '
                        'stornierbar',
                        style: TextStyle(color: T.muted),
                      ),
                    ],
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => _confirmBooking(parkingSpace, totalCents),
                  child: Text(
                    busy
                        ? 'Reservierung wird bestätigt …'
                        : 'Reservierung bestätigen',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBooking(
    ParkingSpace parkingSpace,
    int totalCents,
  ) async {
    if (plate.text.trim().isEmpty) {
      setState(() => error = 'Bitte gib ein Kennzeichen an.');
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final booking = BookingRecord(
      id: id,
      parkingId: parkingSpace.id,
      title: parkingSpace.title,
      reference: 'FR-${id.substring(id.length - 6)}',
      plate: plate.text.trim().toUpperCase(),
      status: 'confirmed',
      start: selectedStart,
      end: selectedEnd,
      totalCents: totalCents,
    );

    try {
      await betaBookings.create(booking);
      if (mounted) {
        context.go('/booking/$id/confirmed');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Reservierung konnte nicht gespeichert werden.';
        });
      }
    }
  }
}

Future<BookingRecord?> _booking(String id) async {
  final bookings = await betaBookings.all();
  for (final booking in bookings) {
    if (booking.id == id) {
      return booking;
    }
  }
  return null;
}

class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return BetaScaffold(
      title: 'Reservierung bestätigt',
      child: FutureBuilder<BookingRecord?>(
        future: _booking(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final booking = snapshot.data;
          if (booking == null) {
            return const Center(child: Text('Buchung nicht gefunden.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: _panel(
                  Column(
                    children: [
                      const CircleAvatar(
                        radius: 36,
                        backgroundColor: T.mintSoft,
                        child: Icon(Icons.check, color: T.success, size: 42),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Dein Stellplatz ist reserviert',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        'Lokale Beta-Buchung',
                        style: TextStyle(
                          color: T.warning,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(booking.title),
                      Text('${_date(booking.start)} · ${booking.plate}'),
                      Text(
                        'Buchungsnummer ${booking.reference}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Geschützter Zugang: Die genaue Adresse wird im '
                        'lokalen Modus nicht gespeichert. Diese Buchung wird '
                        'nicht zwischen Geräten synchronisiert.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () =>
                            context.go('/bookings/${booking.id}/pass'),
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Parking Pass öffnen'),
                      ),
                      TextButton(
                        onPressed: () => context.go('/bookings'),
                        child: const Text('Alle Buchungen'),
                      ),
                      TextButton(
                        onPressed: () => context.go('/discover'),
                        child: const Text('Zurück zur Karte'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsState();
}

class _BookingsState extends State<BookingsScreen> {
  @override
  Widget build(BuildContext context) {
    return BetaScaffold(
      title: 'Meine Buchungen',
      actions: [
        IconButton(
          tooltip: 'Abmelden',
          onPressed: () async {
            await betaAuth.logout();
            if (context.mounted) {
              context.go('/login');
            }
          },
          icon: const Icon(Icons.logout),
        ),
      ],
      child: FutureBuilder<List<BookingRecord>>(
        future: betaBookings.all(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = snapshot.data!;
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 60,
                    color: T.muted,
                  ),
                  const Text(
                    'Noch keine Buchungen',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/discover'),
                    child: const Text('Stellplatz entdecken'),
                  ),
                ],
              ),
            );
          }

          final active = bookings
              .where((booking) => booking.status == 'confirmed')
              .toList();
          final cancelled = bookings
              .where((booking) => booking.status == 'cancelled')
              .toList();

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                if (active.isNotEmpty) ...[
                  const _Heading('Bevorstehend'),
                  ...active.map(
                    (booking) => _BookingCard(
                      booking,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ],
                if (cancelled.isNotEmpty) ...[
                  const _Heading('Storniert'),
                  ...cancelled.map(
                    (booking) => _BookingCard(
                      booking,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ],
                const _Heading('Abgeschlossen'),
                const Text(
                  'Noch keine abgeschlossenen Buchungen.',
                  style: TextStyle(color: T.muted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard(this.booking, {required this.onChanged});

  final BookingRecord booking;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cancelled = booking.status == 'cancelled';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  cancelled ? 'Storniert' : 'Bestätigt',
                  style: TextStyle(
                    color: cancelled ? T.muted : T.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Text('${_date(booking.start)} · ${booking.plate}'),
            Text('${booking.reference} · ${_money(booking.totalCents)}'),
            if (!cancelled)
              Wrap(
                children: [
                  TextButton(
                    onPressed: () =>
                        context.go('/bookings/${booking.id}/pass'),
                    child: const Text('Parking Pass öffnen'),
                  ),
                  TextButton(
                    onPressed: () => _cancel(context),
                    child: const Text('Stornieren'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buchung stornieren?'),
        content: const Text(
          'Im Beta-Modus ist die Stornierung bis eine Stunde vor Beginn '
          'kostenfrei.',
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

    if (confirmed == true) {
      await betaBookings.cancel(booking.id);
      onChanged();
    }
  }
}

class ParkingPassScreen extends StatelessWidget {
  const ParkingPassScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return BetaScaffold(
      title: 'Parking Pass',
      child: FutureBuilder<BookingRecord?>(
        future: _booking(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final booking = snapshot.data;
          if (booking == null) {
            return const Center(child: Text('Buchung nicht gefunden.'));
          }
          if (booking.status != 'confirmed') {
            return const Center(
              child: Text(
                'Dieser Parking Pass ist nach der Stornierung nicht mehr '
                'gültig.',
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _panel(
                  Column(
                    children: [
                      const Text(
                        'FREIRAUM',
                        style: TextStyle(
                          letterSpacing: 4,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'LOKALER BETA-PASS',
                        style: TextStyle(
                          color: T.warning,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      QrImageView(
                        data: 'LOCAL-BETA-PASS:${booking.id}',
                        size: 210,
                        semanticsLabel: 'QR-Code des lokalen Beta-Passes',
                      ),
                      Text(
                        booking.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '${_date(booking.start)} – '
                        '${booking.end.hour.toString().padLeft(2, '0')}:00 Uhr',
                      ),
                      Text(
                        booking.plate,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(booking.reference),
                      const Divider(height: 28),
                      const Text(
                        'Kein echter Torzugang · geschützte Adresse nicht '
                        'lokal verfügbar.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Diesen Pass nicht teilen.',
                        style: TextStyle(
                          color: T.warning,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Widget _tag(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: T.mintSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}

Widget _panel(Widget child) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: T.surface,
      borderRadius: BorderRadius.circular(T.radius),
      border: Border.all(color: T.line),
      boxShadow: T.shadowSmall,
    ),
    child: child,
  );
}
