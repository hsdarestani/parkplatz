import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../config/design_tokens.dart';
import '../../../features/parking/data/providers.dart';
import '../../../features/search/presentation/search_controller.dart';
import '../../../services/map/map_provider.dart';
import '../../../shared/models/models.dart';

class FreiraumMap extends ConsumerStatefulWidget {
  final bool resolving;
  const FreiraumMap({super.key, this.resolving = false});

  @override
  ConsumerState<FreiraumMap> createState() => _FreiraumMapState();
}

class _FreiraumMapState extends ConsumerState<FreiraumMap> {
  final _controller = MapController();
  final _provider = OpenStreetMapProvider();

  @override
  Widget build(BuildContext context) {
    final spaces = ref.watch(parkingResultsListProvider);
    final selectedId = ref.watch(selectedParkingIdProvider);
    final query = ref.watch(searchProvider);
    final selected = spaces.where((s) => s.id == selectedId).firstOrNull;
    final center = selected != null
        ? LatLng(selected.lat, selected.lng)
        : LatLng(
            query.destination?.lat ?? 50.1109,
            query.destination?.lng ?? 8.6821,
          );

    return Semantics(
      label: 'Interaktive Frankfurt-Karte mit ungefähren Stellplatzpositionen',
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
                initialCenter: center,
                initialZoom: 13.2,
                minZoom: 11,
                maxZoom: 17),
            children: [
              TileLayer(
                urlTemplate: _provider.tileTemplate,
                userAgentPackageName: _provider.userAgentPackageName,
                errorTileCallback: (_, __, ___) {},
              ),
              MarkerLayer(
                markers: [
                  if (query.destination != null)
                    Marker(
                      point: LatLng(
                          query.destination!.lat, query.destination!.lng),
                      width: 84,
                      height: 84,
                      child: _DestinationPulse(label: query.destination!.name),
                    ),
                  ...spaces.asMap().entries.map((entry) {
                    final space = entry.value;
                    final selected = space.id == selectedId;
                    final offset = _collisionOffset(entry.key);
                    return Marker(
                      point: LatLng(space.lat + offset.latitude,
                          space.lng + offset.longitude),
                      width: selected ? 210 : 92,
                      height: selected ? 78 : 48,
                      child: _ParkingBeacon(
                        space: space,
                        selected: selected,
                        onTap: () {
                          ref.read(selectedParkingIdProvider.notifier).state =
                              space.id;
                          _controller.move(LatLng(space.lat, space.lng), 14.7);
                          SemanticsService.announce('${space.title} ausgewählt',
                              Directionality.of(context));
                        },
                      ),
                    );
                  }),
                ],
              ),
              RichAttributionWidget(
                attributions: [TextSourceAttribution(_provider.attribution)],
              ),
            ],
          ),
          const Positioned.fill(
            child: IgnorePointer(child: _FallbackFrankfurtLayer()),
          ),
          Positioned(
            right: 14,
            bottom: 18,
            child: _MapBadge(
              text: widget.resolving
                  ? 'Verfügbarkeit wird geprüft'
                  : 'Deine Ankunft ist vorbereitet',
            ),
          ),
        ],
      ),
    );
  }

  LatLng _collisionOffset(int index) {
    final angle = index * .78;
    final radius = index % 3 == 0 ? .00045 : .00022;
    return LatLng(math.sin(angle) * radius, math.cos(angle) * radius);
  }
}

class _ParkingBeacon extends StatelessWidget {
  final ParkingSpace space;
  final bool selected;
  final VoidCallback onTap;
  const _ParkingBeacon({
    required this.space,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${space.title}, ${space.walkingMinutes} Minuten zu Fuß, ${space.hourlyPrice.toStringAsFixed(0)} Euro pro Stunde',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: T.normal,
          curve: T.emphasized,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 12 : 9,
            vertical: selected ? 10 : 7,
          ),
          decoration: BoxDecoration(
            color: selected ? T.ink : T.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? T.mint : T.mint,
              width: selected ? 3 : 1.5,
            ),
            boxShadow: selected ? T.shadowLarge : T.markerShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: T.mint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                selected
                    ? '${space.walkingMinutes} Min · ${space.hourlyPrice.toStringAsFixed(0)} €'
                    : '${space.hourlyPrice.toStringAsFixed(0)} €',
                style: TextStyle(
                  color: selected ? Colors.white : T.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: selected ? 13 : 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationPulse extends StatelessWidget {
  final String label;
  const _DestinationPulse({required this.label});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Ziel $label',
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: T.amber.withOpacity(.20),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: T.amber,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: T.shadow,
              ),
            ),
            const Icon(Icons.flag_rounded, color: T.ink, size: 18),
          ],
        ),
      );
}

class _MapBadge extends StatelessWidget {
  final String text;
  const _MapBadge({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: T.mapOverlay,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: T.line),
          boxShadow: T.shadowSmall,
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w800, color: T.ink),
        ),
      );
}

class _FallbackFrankfurtLayer extends StatelessWidget {
  const _FallbackFrankfurtLayer();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _FallbackPainter(), size: Size.infinite);
}

class _FallbackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = T.porcelain.withOpacity(.28),
    );
    paint.color = T.ink.withOpacity(.06);
    paint.strokeWidth = 1;
    for (double x = -80; x < size.width; x += 70) {
      canvas.drawLine(Offset(x, 0), Offset(x + 260, size.height), paint);
    }
    for (double y = 40; y < size.height; y += 58) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 170), paint);
    }
    paint.color = const Color(0xFF8DB7C7).withOpacity(.20);
    paint.strokeWidth = 20;
    final river = ui.Path()
      ..moveTo(-20, size.height * .58)
      ..cubicTo(
        size.width * .25,
        size.height * .52,
        size.width * .42,
        size.height * .68,
        size.width + 20,
        size.height * .56,
      );
    canvas.drawPath(river, paint);
    final labels = {
      'Gallus': const Offset(.22, .42),
      'Westend': const Offset(.42, .30),
      'Innenstadt': const Offset(.56, .42),
      'Ostend': const Offset(.73, .52),
      'Main': const Offset(.49, .62),
    };
    for (final entry in labels.entries) {
      final tp = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: TextStyle(
            color: T.ink.withOpacity(.22),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(size.width * entry.value.dx, size.height * entry.value.dy),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
