import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/models/models.dart';
import 'booking_ui_components.dart';

class ParkingDetailHero extends StatelessWidget {
  const ParkingDetailHero({
    super.key,
    required this.space,
    required this.owner,
  });

  final ParkingSpace space;
  final bool owner;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final narrow = constraints.maxWidth < 390;
          final content = _HeroText(
            space: space,
            owner: owner,
            compact: compact,
            narrow: narrow,
          );
          final decoration = BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A1828), T.inkSoft, Color(0xFF12354A)],
            ),
            borderRadius: BorderRadius.circular(compact ? 26 : T.radiusSpacious),
            boxShadow: T.shadowLarge,
          );
          if (compact) {
            return Container(
              width: double.infinity,
              padding: EdgeInsets.all(narrow ? 18 : 22),
              decoration: decoration,
              child: content,
            );
          }
          return Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 280),
            padding: const EdgeInsets.all(30),
            decoration: decoration,
            child: Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: 24),
                Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.08),
                    borderRadius: BorderRadius.circular(48),
                    border: Border.all(color: Colors.white.withOpacity(.11)),
                  ),
                  child: Icon(
                    space.covered
                        ? Icons.garage_rounded
                        : Icons.local_parking_rounded,
                    size: 112,
                    color: T.mint,
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _HeroText extends StatelessWidget {
  const _HeroText({
    required this.space,
    required this.owner,
    required this.compact,
    required this.narrow,
  });

  final ParkingSpace space;
  final bool owner;
  final bool compact;
  final bool narrow;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                icon: owner
                    ? Icons.home_work_outlined
                    : space.instant
                        ? Icons.bolt_outlined
                        : Icons.schedule_outlined,
                text: owner
                    ? 'Dein Stellplatz'
                    : space.instant
                        ? 'Sofort reservierbar'
                        : 'Anfrage',
              ),
              _Pill(
                icon: space.verified
                    ? Icons.verified_outlined
                    : Icons.shield_outlined,
                text: space.verified ? 'Verifiziert' : 'Noch nicht verifiziert',
              ),
              if (space.free)
                const _Pill(
                  icon: Icons.money_off_csred_outlined,
                  text: 'Kostenlos',
                ),
            ],
          ),
          SizedBox(height: compact ? 16 : 20),
          SizedBox(
            width: double.infinity,
            child: Text(
              space.title,
              maxLines: compact ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              textWidthBasis: TextWidthBasis.parent,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontSize: compact ? (narrow ? 27 : 32) : 44,
                    height: 1.05,
                    letterSpacing: -.8,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${space.district} · nahe ${space.landmark}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white70,
              fontSize: compact ? 14 : 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: compact ? 16 : 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Metric(
                icon: Icons.star_rounded,
                value: space.reviewCount == 0
                    ? 'Neu'
                    : space.rating.toStringAsFixed(1),
                label: '${space.reviewCount} Bewertungen',
              ),
              _Metric(
                icon: space.free ? Icons.check_circle_outline : Icons.euro,
                value: space.free
                    ? '0,00 €'
                    : bookingMoney((space.hourlyPrice * 100).round()),
                label: 'pro Stunde',
              ),
              _Metric(
                icon: parkingAccessIcon(space.access),
                value: space.indoor ? 'Innen' : 'Außen',
                label: space.accessLabel(),
              ),
            ],
          ),
        ],
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(.11)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: T.mint, size: 17),
            const SizedBox(width: 7),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.09)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: T.mint, size: 19),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      );
}

IconData parkingAccessIcon(AccessType access) => switch (access) {
      AccessType.offen => Icons.wb_sunny_outlined,
      AccessType.schranke => Icons.horizontal_rule_rounded,
      AccessType.tor => Icons.fence_outlined,
      AccessType.tiefgarage => Icons.garage_outlined,
      AccessType.rezeption => Icons.meeting_room_outlined,
    };
