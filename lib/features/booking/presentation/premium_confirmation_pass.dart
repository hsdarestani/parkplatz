import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_motion.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../parking/data/providers.dart';
import '../data/repositories.dart';
import 'booking_ui_components.dart';

class PremiumConfirmationScreen extends ConsumerWidget {
  const PremiumConfirmationScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FreiraumScaffold(
        title: 'Reservierung bestätigt',
        subtitle: 'Dein Parking Pass ist bereit.',
        activePath: '/bookings',
        child: FutureBuilder<BookingRecord?>(
          future: ref.read(bookingRepositoryProvider).detail(id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return snapshot.connectionState == ConnectionState.done
                  ? const Center(child: Text('Buchung nicht gefunden.'))
                  : const Center(child: CircularProgressIndicator());
            }
            final booking = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: MotionReveal(
                      child: BookingSurfaceCard(
                        elevated: true,
                        child: Column(
                          children: [
                            const AnimatedCheck(),
                            const SizedBox(height: 20),
                            Text(
                              'Dein Stellplatz ist reserviert',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${booking.title} · ${bookingDateTime(booking.start)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: T.muted,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: T.surfaceRaised,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: T.line),
                              ),
                              child: Column(
                                children: [
                                  _ConfirmationLine(
                                    label: 'Buchungsnummer',
                                    value: booking.reference,
                                  ),
                                  _ConfirmationLine(
                                    label: 'Fahrzeug',
                                    value: booking.plate,
                                  ),
                                  _ConfirmationLine(
                                    label: 'Gesamtpreis',
                                    value: bookingMoney(booking.totalCents),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              onPressed: () =>
                                  context.go('/bookings/${booking.id}/pass'),
                              icon: const Icon(Icons.qr_code_2),
                              label: const Text('Parking Pass öffnen'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => context.go('/bookings'),
                              child: const Text('Alle Buchungen ansehen'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class PremiumParkingPassScreen extends ConsumerWidget {
  const PremiumParkingPassScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FreiraumScaffold(
        title: 'Parking Pass',
        subtitle: 'Sicherer Zugang zu deiner bestätigten Buchung.',
        activePath: '/bookings',
        child: FutureBuilder<BookingRecord?>(
          future: ref.read(bookingRepositoryProvider).detail(id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return snapshot.connectionState == ConnectionState.done
                  ? const Center(child: Text('Buchung nicht gefunden.'))
                  : const Center(child: CircularProgressIndicator());
            }
            final booking = snapshot.data!;
            if (booking.status != 'confirmed') {
              return const _InvalidPass();
            }
            final token = booking.localBeta
                ? 'LOCAL-BETA-PASS:${booking.id}'
                : booking.parkingPassToken;
            if (token == null || token.isEmpty) {
              return const Center(
                child: Text('Parking Pass konnte nicht geladen werden.'),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: MotionReveal(
                      child: _PassCard(booking: booking, token: token),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _PassCard extends StatelessWidget {
  const _PassCard({required this.booking, required this.token});

  final BookingRecord booking;
  final String token;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(36),
          boxShadow: T.shadowLarge,
          border: Border.all(color: T.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [T.ink, T.inkSoft],
                ),
              ),
              child: const Column(
                children: [
                  Text(
                    'FREIRAUM',
                    style: TextStyle(
                      color: Colors.white,
                      letterSpacing: 5,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'DIGITAL PARKING PASS',
                    style: TextStyle(
                      color: T.mint,
                      letterSpacing: 1.5,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: T.line),
                    ),
                    child: QrImageView(data: token, size: 220),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    booking.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${bookingDateTime(booking.start)} – ${bookingTime(booking.end)} Uhr',
                    style: const TextStyle(
                      color: T.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    booking.plate,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (booking.exactAddress != null) ...[
                    const Divider(height: 32),
                    _PassLine(
                      icon: Icons.location_on_outlined,
                      title: 'Genaue Adresse',
                      value: booking.exactAddress!,
                    ),
                    if (booking.entranceInstructions != null)
                      _PassLine(
                        icon: Icons.meeting_room_outlined,
                        title: 'Zufahrt',
                        value: booking.entranceInstructions!,
                      ),
                    if (booking.accessCode != null)
                      _PassLine(
                        icon: Icons.key_outlined,
                        title: 'Zugangscode',
                        value: booking.accessCode!,
                        trailing: IconButton(
                          tooltip: 'Code kopieren',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: booking.accessCode!),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Zugangscode wurde kopiert.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_outlined),
                        ),
                      ),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: T.amberSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_off_outlined, color: T.warning),
                        SizedBox(width: 8),
                        Text(
                          'Diesen Pass nicht teilen',
                          style: TextStyle(
                            color: T.warning,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _InvalidPass extends StatelessWidget {
  const _InvalidPass();

  @override
  Widget build(BuildContext context) => Center(
        child: MotionReveal(
          child: BookingSurfaceCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.qr_code_2_outlined,
                  size: 72,
                  color: T.muted,
                ),
                const SizedBox(height: 16),
                Text(
                  'Dieser Parking Pass ist nicht mehr gültig',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Die Buchung wurde storniert oder ist nicht mehr aktiv.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: T.muted),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => context.go('/bookings'),
                  child: const Text('Zur Buchungsübersicht'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ConfirmationLine extends StatelessWidget {
  const _ConfirmationLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: T.muted)),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _PassLine extends StatelessWidget {
  const _PassLine({
    required this.icon,
    required this.title,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: T.mintSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: T.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: T.muted)),
                  SelectableText(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}
