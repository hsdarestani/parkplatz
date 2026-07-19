import 'dart:math' as math;

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
  const FreiraumMap({super.key, this.resolving = false});

  final bool resolving;

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
    final selected = spaces.where((space) => space.id == selectedId).firstOrNull;
    final center = selected != null
        ? LatLng(selected.lat, selected.lng)
        : LatLng(
            query.destination?.lat ?? 50.1109,
            query.destination?.lng ?? 8.6821,
          );
    final compact = MediaQuery.sizeOf(context).width < 620;

    return Semantics(
      label: 'Interaktive Frankfurt-Karte mit ungefähren Stellplatzpositionen',
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: center,
                initialZoom: compact ? 12.8 : 13.2,
                minZoom: 11,
                maxZoom: 17,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: _provider.tileTemplate,
                  userAgentPackageName: _provider.userAgentPackageName,
                  errorTileCallback: (_, __, ___) {},
                ),
                MarkerLayer(
                  rotate: false,
                  markers: [
                    if (query.destination != null)
                      Marker(
                        point: LatLng(
                          query.destination!.lat,
                          query.destination!.lng,
                        ),
                        width: 64,
                        height: 64,
                        child: _DestinationPulse(label: query.destination!.name),
                      ),
                    ...spaces.asMap().entries.map((entry) {
                      final space = entry.value;
                      final isSelected = space.id == selectedId;
                      final offset = _collisionOffset(entry.key);
                      return Marker(
                        point: LatLng(
                          space.lat + offset.latitude,
                          space.lng + offset.longitude,
                        ),
                        width: isSelected
                            ? compact
                                ? 150
                                : 190
                            : 78,
                        height: isSelected ? 58 : 44,
                        alignment: Alignment.center,
                        child: _ParkingBeacon(
                          space: space,
                          selected: isSelected,
                          onTap: () {
                            ref.read(selectedParkingIdProvider.notifier).state =
                                space.id;
                            _controller.move(
                              LatLng(space.lat, space.lng),
                              compact ? 14.1 : 14.7,
                            );
                            SemanticsService.announce(
                              '${space.title} ausgewählt',
                              Directionality.of(context),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution(_provider.attribution),
                  ],
                ),
              ],
            ),
            if (widget.resolving)
              const Positioned(
                right: 14,
                bottom: 18,
                child: _MapBadge(text: 'Verfügbarkeit wird geprüft'),
              ),
          ],
        ),
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
  const _ParkingBeacon({
    required this.space,
    required this.selected,
    required this.onTap,
  });

  final ParkingSpace space;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label:
            '${space.title}, ${space.walkingMinutes} Minuten zu Fuß, ${space.hourlyPrice.toStringAsFixed(0)} Euro pro Stunde',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: T.normal,
            curve: T.emphasized,
            padding: EdgeInsets.symmetric(
              horizontal: selected ? 11 : 9,
              vertical: selected ? 9 : 7,
            ),
            decoration: BoxDecoration(
              color: selected ? T.ink : T.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: T.mint,
                width: selected ? 2.5 : 1.5,
              ),
              boxShadow: selected ? T.shadowLarge : T.markerShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
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
                Flexible(
                  child: Text(
                    selected
                        ? '${space.walkingMinutes} Min · ${space.hourlyPrice.toStringAsFixed(0)} €'
                        : '${space.hourlyPrice.toStringAsFixed(0)} €',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : T.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: selected ? 13 : 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DestinationPulse extends StatelessWidget {
  const _DestinationPulse({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Ziel $label',
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: T.amber.withOpacity(.20),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: T.amber,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: T.shadow,
              ),
            ),
            const Icon(Icons.flag_rounded, color: T.ink, size: 17),
          ],
        ),
      );
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.text});

  final String text;

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
