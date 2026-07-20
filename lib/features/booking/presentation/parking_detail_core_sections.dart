import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/models/models.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../parking/data/providers.dart';
import '../../search/presentation/search_controller.dart';
import 'booking_ui_components.dart';
import 'parking_detail_hero.dart';

class ParkingDetailsColumn extends StatelessWidget {
  const ParkingDetailsColumn({super.key, required this.space});

  final ParkingSpace space;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          BookingSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BookingSectionTitle(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Was dich erwartet',
                  subtitle: 'Alle wichtigen Eigenschaften auf einen Blick.',
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth < 540
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _Feature(
                          width: width,
                          icon: Icons.straighten_outlined,
                          title: 'Fahrzeugmaße',
                          value: space.dimensions(),
                        ),
                        _Feature(
                          width: width,
                          icon: parkingAccessIcon(space.access),
                          title: 'Zufahrt',
                          value: space.accessLabel(),
                        ),
                        _Feature(
                          width: width,
                          icon: Icons.roofing_outlined,
                          title: 'Schutz',
                          value: space.covered ? 'Überdacht' : 'Freifläche',
                        ),
                        _Feature(
                          width: width,
                          icon: Icons.ev_station_outlined,
                          title: 'E-Mobilität',
                          value: space.ev ? 'Lademöglichkeit' : 'Ohne Ladepunkt',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BookingSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BookingSectionTitle(
                  icon: Icons.lock_outline,
                  title: 'Privatsphäre und Ankunft',
                  subtitle: 'Adresse und Zugang bleiben bis zur Bestätigung geschützt.',
                ),
                const SizedBox(height: 18),
                const _TrustLine(
                  icon: Icons.location_off_outlined,
                  text: 'Öffentlich ist nur der ungefähre Standort sichtbar.',
                ),
                const _TrustLine(
                  icon: Icons.qr_code_2,
                  text: 'Nach Bestätigung wird der Parking Pass freigeschaltet.',
                ),
                const _TrustLine(
                  icon: Icons.verified_user_outlined,
                  text: 'Auch Sofort- und Gratisbuchungen brauchen Bestätigung.',
                ),
                _TrustLine(
                  icon: Icons.rule_outlined,
                  text: space.cancellationSummary,
                ),
              ],
            ),
          ),
        ],
      );
}

class ParkingBookingPanel extends ConsumerWidget {
  const ParkingBookingPanel({
    super.key,
    required this.space,
    required this.owner,
    required this.checkingOwner,
  });

  final ParkingSpace space;
  final bool owner;
  final bool checkingOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchProvider);
    final favorite = ref.watch(favoritesProvider).contains(space.id);
    final fits = query.vehicle == null || space.fits(query.vehicle!);
    final total = (space.hourlyPrice * 100 * query.hours).round();
    return BookingSurfaceCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: BookingSectionTitle(
                  icon: Icons.calendar_month_outlined,
                  title: 'Zeitraum wählen',
                  subtitle: 'Datum, Einfahrt, Ausfahrt und Dauer anpassen.',
                ),
              ),
              IconButton.filledTonal(
                tooltip: favorite ? 'Nicht mehr merken' : 'Stellplatz merken',
                onPressed: () =>
                    ref.read(favoritesProvider.notifier).toggle(space.id),
                icon: Icon(
                  favorite ? Icons.bookmark_rounded : Icons.bookmark_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          PremiumBookingTimeSelector(
            onChanged: () => ref.invalidate(parkingResultsProvider),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: T.surfaceRaised,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: T.line),
            ),
            child: Row(
              children: [
                Icon(
                  space.free
                      ? Icons.money_off_csred_outlined
                      : Icons.receipt_long_outlined,
                  color: T.success,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Gesamtpreis',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  space.free ? 'Kostenlos' : bookingMoney(total),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (!fits) ...[
            const SizedBox(height: 12),
            const Text(
              'Das gewählte Fahrzeug überschreitet die zulässigen Maße.',
              style: TextStyle(color: T.warning, fontWeight: FontWeight.w800),
            ),
          ],
          if (owner) ...[
            const SizedBox(height: 12),
            const Text(
              'Das ist dein eigener Stellplatz.',
              style: TextStyle(color: T.warning, fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: checkingOwner || !fits
                ? null
                : owner
                    ? () => context.go('/host/${space.id}/manage')
                    : () => context.go('/checkout/${space.id}'),
            icon: Icon(
              owner ? Icons.settings_outlined : Icons.arrow_forward_rounded,
            ),
            label: Text(
              checkingOwner
                  ? 'Konto wird geprüft …'
                  : owner
                      ? 'Stellplatz verwalten'
                      : space.free
                          ? 'Kostenlose Anfrage senden'
                          : 'Sicher weiter zur Buchung',
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.surfaceRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: T.line),
        ),
        child: Row(
          children: [
            Icon(icon, color: T.success),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: T.muted)),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _TrustLine extends StatelessWidget {
  const _TrustLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: T.locked, size: 20),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
