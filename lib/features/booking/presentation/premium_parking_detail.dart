import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../host/data/host_repository.dart';
import '../../parking/data/providers.dart';
import 'booking_screens.dart' as legacy;
import 'booking_ui_components.dart';

class PremiumParkingDetailScreen extends ConsumerStatefulWidget {
  const PremiumParkingDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<PremiumParkingDetailScreen> createState() =>
      _PremiumParkingDetailScreenState();
}

class _PremiumParkingDetailScreenState
    extends ConsumerState<PremiumParkingDetailScreen> {
  late Future<bool> ownership;

  @override
  void initState() {
    super.initState();
    ownership = _ownsSpace();
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
      title: 'Stellplatz entdecken',
      subtitle: 'Details, Zeitraum und sichere Buchung.',
      activePath: '/discover',
      child: spaceState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => PremiumRetryState(
          message: 'Stellplatz konnte nicht geladen werden.',
          onRetry: () => ref.invalidate(parkingSpaceProvider(widget.id)),
        ),
        data: (space) {
          if (space == null) {
            return const Center(child: Text('Stellplatz nicht gefunden.'));
          }
          return FutureBuilder<bool>(
            future: ownership,
            builder: (context, snapshot) => _ParkingDetailBody(
              space: space,
              owner: snapshot.data ?? false,
              checkingOwner: snapshot.connectionState != ConnectionState.done,
            ),
          );
        },
      ),
    );
  }
}

class _ParkingDetailBody extends ConsumerStatefulWidget {
  const _ParkingDetailBody({
    required this.space,
    required this.owner,
    required this.checkingOwner,
  });

  final ParkingSpace space;
  final bool owner;
  final bool checkingOwner;

  @override
  ConsumerState<_ParkingDetailBody> createState() => _ParkingDetailBodyState();
}

class _ParkingDetailBodyState extends ConsumerState<_ParkingDetailBody> {
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    final pagePadding = compact ? 14.0 : 24.0;
    final hours = math.max(
      1,
      legacy.selectedEnd.difference(legacy.selectedStart).inHours,
    );
    final totalCents = (widget.space.hourlyPrice * 100 * hours).round();
    final favorite = ref.watch(favoritesProvider).contains(widget.space.id);

    Future<void> toggleFavorite() async {
      await ref.read(favoritesProvider.notifier).toggle(widget.space.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              favorite ? 'Favorit entfernt.' : 'Stellplatz gespeichert.',
            ),
          ),
        );
    }

    final details = _DetailsColumn(space: widget.space);
    final booking = _BookingPanel(
      space: widget.space,
      owner: widget.owner,
      checkingOwner: widget.checkingOwner,
      totalCents: totalCents,
      favorite: favorite,
      onFavorite: toggleFavorite,
      onTimeChanged: () => setState(() {}),
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        pagePadding,
        pagePadding,
        pagePadding,
        pagePadding + MediaQuery.paddingOf(context).bottom + (compact ? 88 : 24),
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ParkingDetailHero(space: widget.space, owner: widget.owner),
                SizedBox(height: compact ? 14 : 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 860) {
                      return Column(
                        children: [
                          details,
                          const SizedBox(height: 16),
                          booking,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: details),
                        const SizedBox(width: 22),
                        Expanded(flex: 4, child: booking),
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
}

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
          final veryNarrow = constraints.maxWidth < 390;
          final content = _HeroContent(
            space: space,
            owner: owner,
            compact: compact,
            veryNarrow: veryNarrow,
          );

          final decoration = BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A1828), T.inkSoft, Color(0xFF12354A)],
            ),
            borderRadius: BorderRadius.circular(
              compact ? 26 : T.radiusSpacious,
            ),
            boxShadow: T.shadowLarge,
          );

          if (compact) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: decoration,
              child: content,
            );
          }

          return Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 280),
            padding: const EdgeInsets.all(30),
            clipBehavior: Clip.hardEdge,
            decoration: decoration,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  right: -20,
                  top: -40,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: T.mint.withOpacity(.07),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 24),
                    Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.08),
                        borderRadius: BorderRadius.circular(48),
                        border: Border.all(
                          color: Colors.white.withOpacity(.11),
                        ),
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
              ],
            ),
          );
        },
      );
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({
    required this.space,
    required this.owner,
    required this.compact,
    required this.veryNarrow,
  });

  final ParkingSpace space;
  final bool owner;
  final bool compact;
  final bool veryNarrow;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DarkPill(
                  icon: owner ? Icons.home_work_outlined : Icons.bolt_outlined,
                  text: owner
                      ? 'Dein Stellplatz'
                      : space.instant
                          ? 'Sofort buchbar'
                          : 'Anfrage',
                ),
                _DarkPill(
                  icon: space.verified
                      ? Icons.verified_outlined
                      : Icons.shield_outlined,
                  text: space.verified
                      ? 'Verifiziert'
                      : 'Noch nicht verifiziert',
                ),
              ],
            ),
            SizedBox(height: compact ? 16 : 20),
            SizedBox(
              width: double.infinity,
              child: Text(
                space.title,
                maxLines: compact ? 3 : 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                textWidthBasis: TextWidthBasis.parent,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontSize: compact ? (veryNarrow ? 28 : 32) : 44,
                      height: 1.04,
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
                _HeroMetric(
                  icon: Icons.directions_walk,
                  value: '${space.walkingMinutes} Min.',
                  label: 'zu Fuß',
                  compact: compact,
                ),
                _HeroMetric(
                  icon: Icons.star_rounded,
                  value: space.rating.toStringAsFixed(1),
                  label: '${space.reviewCount} Bewertungen',
                  compact: compact,
                ),
                _HeroMetric(
                  icon: Icons.euro,
                  value: bookingMoney((space.hourlyPrice * 100).round()),
                  label: 'pro Stunde',
                  compact: compact,
                ),
              ],
            ),
          ],
        ),
      );
}

class _DetailsColumn extends StatelessWidget {
  const _DetailsColumn({required this.space});

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
                    final tileWidth = constraints.maxWidth < 540
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _FeatureTile(
                          width: tileWidth,
                          icon: Icons.straighten_outlined,
                          title: 'Fahrzeugmaße',
                          value: space.dimensions(),
                        ),
                        _FeatureTile(
                          width: tileWidth,
                          icon: Icons.meeting_room_outlined,
                          title: 'Zufahrt',
                          value: space.accessLabel(),
                        ),
                        _FeatureTile(
                          width: tileWidth,
                          icon: Icons.roofing_outlined,
                          title: 'Schutz',
                          value: space.covered ? 'Überdacht' : 'Freifläche',
                        ),
                        _FeatureTile(
                          width: tileWidth,
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
                  subtitle: 'Die genaue Adresse bleibt bis zur Bestätigung geschützt.',
                ),
                const SizedBox(height: 18),
                const _TrustLine(
                  icon: Icons.location_off_outlined,
                  text: 'Öffentlich ist nur der ungefähre Standort sichtbar.',
                ),
                const _TrustLine(
                  icon: Icons.qr_code_2,
                  text: 'Nach der Bestätigung erhältst du deinen Parking Pass.',
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

class _BookingPanel extends StatelessWidget {
  const _BookingPanel({
    required this.space,
    required this.owner,
    required this.checkingOwner,
    required this.totalCents,
    required this.favorite,
    required this.onFavorite,
    required this.onTimeChanged,
  });

  final ParkingSpace space;
  final bool owner;
  final bool checkingOwner;
  final int totalCents;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onTimeChanged;

  @override
  Widget build(BuildContext context) => BookingSurfaceCard(
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: BookingSectionTitle(
                    icon: Icons.calendar_month_outlined,
                    title: 'Zeitraum wählen',
                    subtitle: 'Datum und Startzeit für die Buchung.',
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onFavorite,
                  tooltip: favorite ? 'Nicht mehr merken' : 'Stellplatz merken',
                  icon: Icon(
                    favorite ? Icons.bookmark_rounded : Icons.bookmark_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            PremiumBookingTimeSelector(onChanged: onTimeChanged),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: T.surfaceRaised,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: T.line),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  const SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voraussichtlicher Gesamtpreis',
                          style: TextStyle(
                            color: T.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Der Server bestätigt den verbindlichen Preis.',
                          style: TextStyle(color: T.subtle, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    bookingMoney(totalCents),
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (owner) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: T.amberSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: T.amber),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: T.warning),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Das ist dein eigener Stellplatz. Du kannst ihn verwalten, aber nicht selbst buchen.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: checkingOwner
                  ? null
                  : owner
                      ? () => context.go('/host')
                      : () => context.go('/checkout/${space.id}'),
              icon: Icon(
                owner ? Icons.settings_outlined : Icons.arrow_forward_rounded,
              ),
              label: Text(
                checkingOwner
                    ? 'Konto wird geprüft …'
                    : owner
                        ? 'Stellplatz verwalten'
                        : 'Sicher weiter zur Buchung',
              ),
            ),
            if (!owner) ...[
              const SizedBox(height: 10),
              const Text(
                'Die genaue Adresse bleibt bis zur Zahlungsbestätigung verborgen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: T.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      );
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
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

class _DarkPill extends StatelessWidget {
  const _DarkPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(.13)),
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

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.compact,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 13,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.09)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: T.mint, size: compact ? 17 : 19),
            const SizedBox(width: 7),
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
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      );
}
