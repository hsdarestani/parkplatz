import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/illustration.dart';
import '../../booking/data/repositories.dart';
import '../../favorites/data/favorites_repository.dart';

class ParkingCard extends ConsumerWidget {
  const ParkingCard({
    super.key,
    required this.s,
    required this.q,
    required this.selected,
    required this.onTap,
    this.onDetails,
    this.compact = false,
  });

  final ParkingSpace s;
  final SearchQuery q;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDetails;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localBeta = ref.watch(appModeProvider) == AppMode.localBeta;
    final favorite = ref.watch(favoritesProvider).contains(s.id);
    final currency = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final fit = q.vehicle == null || s.fits(q.vehicle!);

    void toggleFavorite() {
      ref.read(favoritesProvider.notifier).toggle(s.id);
    }

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${s.title}, ${s.walkingMinutes} Minuten Fußweg, ${currency.format(s.total(q.hours))} gesamt',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(T.radius),
        child: AnimatedContainer(
          duration: T.normal,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? T.surfaceSelected : T.surfaceRaised,
            borderRadius: BorderRadius.circular(T.radius),
            border: Border.all(
              color: selected ? T.mint : T.line,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? T.shadow : T.shadowSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ParkingIllustration(
                    s.visual,
                    width: compact ? 94 : 112,
                    height: compact ? 74 : 86,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: favorite
                                  ? 'Nicht mehr merken'
                                  : 'Stellplatz merken',
                              onPressed: toggleFavorite,
                              icon: Icon(
                                favorite
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_outline_rounded,
                                color: favorite ? T.success : T.muted,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          s.approximate(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: T.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _Signal(
                              text: '${s.walkingMinutes} Min. zu Fuß',
                              icon: Icons.directions_walk,
                            ),
                            const SizedBox(width: 6),
                            _Signal(
                              text: fit ? 'Fahrzeug passt' : 'Maße prüfen',
                              icon: fit ? Icons.check_circle : Icons.straighten,
                              positive: fit,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${currency.format(s.total(q.hours))} gesamt',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${currency.format(s.hourlyPrice)}/Std.',
                    style: const TextStyle(
                      color: T.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.star_rounded, color: T.amber, size: 18),
                  Text(
                    '${s.rating.toStringAsFixed(1)} (${s.reviewCount})',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Pill(
                    text: s.verified
                        ? 'Verifizierter Standort'
                        : localBeta
                            ? 'Demo-geprüft'
                            : 'Nicht verifiziert',
                  ),
                  _Pill(
                    text: s.instant ? 'Sofort verfügbar' : 'Anfrage prüfbar',
                  ),
                  _Pill(text: s.accessLabel()),
                ],
              ),
              if (selected) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: T.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: T.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vorschau für deine Ankunft',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      const _PreviewLine(
                        icon: Icons.lock_outline,
                        text: 'Genaue Zufahrt nach der Buchung',
                      ),
                      _PreviewLine(
                        icon: Icons.payments_outlined,
                        text:
                            '${currency.format(s.total(q.hours))} Gesamtpreis für ${q.hours} Stunden',
                      ),
                      _PreviewLine(
                        icon: Icons.directions_car_filled_outlined,
                        text: fit
                            ? 'Das ausgewählte Fahrzeug passt.'
                            : 'Fahrzeugmaße vor der Buchung prüfen.',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: onDetails,
                              child: const Text('Details ansehen'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: toggleFavorite,
                            icon: Icon(
                              favorite
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_outline_rounded,
                            ),
                            label: Text(favorite ? 'Gemerkt' : 'Merken'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: T.locked),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _Signal extends StatelessWidget {
  const _Signal({
    required this.text,
    required this.icon,
    this.positive = false,
  });

  final String text;
  final IconData icon;
  final bool positive;

  @override
  Widget build(BuildContext context) => Flexible(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: positive ? T.success : T.ink),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: T.porcelain,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: T.line),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
