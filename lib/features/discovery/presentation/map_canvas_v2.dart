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
import '../../../services/routing/walking_routing.dart';
import '../../../shared/models/models.dart';

class FreiraumMapV2 extends ConsumerStatefulWidget {
  const FreiraumMapV2({
    super.key,
    this.resolving = false,
    required this.onMapTap,
  });

  final bool resolving;
  final VoidCallback onMapTap;

  @override
  ConsumerState<FreiraumMapV2> createState() => _FreiraumMapV2State();
}

class _FreiraumMapV2State extends ConsumerState<FreiraumMapV2> {
  final controller = MapController();
  final provider = OpenStreetMapProvider();

  @override
  Widget build(BuildContext context) {
    final spaces = ref.watch(parkingResultsListProvider);
    final selectedId = ref.watch(selectedParkingIdProvider);
    final query = ref.watch(searchProvider);
    final currentLocation = ref.watch(userLocationProvider).valueOrNull;
    final selected = spaces.where((space) => space.id == selectedId).firstOrNull;
    final compact = MediaQuery.sizeOf(context).width < 620;
    final request = _requestFor(selected, query, currentLocation);
    final routeState = request == null
        ? const AsyncValue<WalkingRoute?>.data(null)
        : ref.watch(walkingRouteProvider(request));
    final route = routeState.valueOrNull;

    ref.listen<String?>(selectedParkingIdProvider, (previous, next) {
      if (next == null || next == previous) return;
      final space = ref
          .read(parkingResultsListProvider)
          .where((value) => value.id == next)
          .firstOrNull;
      if (space == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          controller.move(LatLng(space.lat, space.lng), compact ? 14.2 : 14.8);
        }
      });
    });

    ref.listen<AsyncValue<LatLng?>>(userLocationProvider, (previous, next) {
      final location = next.valueOrNull;
      if (location == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.move(location, 14.6);
      });
    });

    final center = selected != null
        ? LatLng(selected.lat, selected.lng)
        : query.destination != null
            ? LatLng(query.destination!.lat, query.destination!.lng)
            : currentLocation ?? const LatLng(50.1109, 8.6821);

    return Semantics(
      label: 'Interaktive Karte mit echten Fußrouten',
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: center,
                initialZoom: compact ? 12.9 : 13.3,
                minZoom: 10,
                maxZoom: 18,
                onTap: (_, __) => widget.onMapTap(),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: provider.tileTemplate,
                  userAgentPackageName: provider.userAgentPackageName,
                  errorTileCallback: (_, __, ___) {},
                ),
                if (route != null && route.geometry.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: route.geometry,
                        strokeWidth: 6,
                        color: T.success,
                        borderStrokeWidth: 2,
                        borderColor: Colors.white,
                      ),
                    ],
                  ),
                MarkerLayer(
                  rotate: false,
                  markers: [
                    if (currentLocation != null)
                      Marker(
                        point: currentLocation,
                        width: 54,
                        height: 54,
                        child: const _CurrentLocationMarker(),
                      ),
                    if (query.destination != null)
                      Marker(
                        point: LatLng(
                          query.destination!.lat,
                          query.destination!.lng,
                        ),
                        width: 62,
                        height: 62,
                        child: _DestinationMarker(
                          label: query.destination!.name,
                        ),
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
                        width: isSelected ? (compact ? 190 : 230) : 84,
                        height: isSelected ? 60 : 46,
                        child: _ParkingMarker(
                          space: space,
                          selected: isSelected,
                          route: isSelected ? route : null,
                          onTap: () {
                            ref.read(selectedParkingIdProvider.notifier).state =
                                space.id;
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
                  attributions: [TextSourceAttribution(provider.attribution)],
                ),
              ],
            ),
            if (routeState.isLoading)
              const Positioned(
                left: 14,
                bottom: 18,
                child: _MapBadge(
                  icon: Icons.route_rounded,
                  text: 'Echte Fußroute wird berechnet',
                ),
              ),
            if (widget.resolving)
              const Positioned(
                right: 14,
                bottom: 18,
                child: _MapBadge(
                  icon: Icons.event_available_rounded,
                  text: 'Verfügbarkeit wird geprüft',
                ),
              ),
          ],
        ),
      ),
    );
  }

  RouteRequest? _requestFor(
    ParkingSpace? space,
    SearchQuery query,
    LatLng? currentLocation,
  ) {
    if (space == null) return null;
    if (query.destination != null) {
      return RouteRequest(
        fromLat: space.lat,
        fromLng: space.lng,
        toLat: query.destination!.lat,
        toLng: query.destination!.lng,
      );
    }
    if (currentLocation != null) {
      return RouteRequest(
        fromLat: currentLocation.latitude,
        fromLng: currentLocation.longitude,
        toLat: space.lat,
        toLng: space.lng,
      );
    }
    return null;
  }

  LatLng _collisionOffset(int index) {
    final angle = index * .78;
    final radius = index % 3 == 0 ? .00045 : .00022;
    return LatLng(math.sin(angle) * radius, math.cos(angle) * radius);
  }
}

class _ParkingMarker extends StatelessWidget {
  const _ParkingMarker({
    required this.space,
    required this.selected,
    required this.route,
    required this.onTap,
  });

  final ParkingSpace space;
  final bool selected;
  final WalkingRoute? route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = space.free ? 'Frei' : '${space.hourlyPrice.toStringAsFixed(0)} €';
    final routeLabel = route == null
        ? null
        : '${route!.durationMinutes} Min. · ${route!.distanceLabel}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: T.normal,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 12 : 9,
          vertical: selected ? 9 : 7,
        ),
        decoration: BoxDecoration(
          color: selected ? T.ink : T.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: T.mint, width: selected ? 2.5 : 1.5),
          boxShadow: selected ? T.shadowLarge : T.markerShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_parking_rounded, color: T.mint, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                selected && routeLabel != null ? '$routeLabel · $price' : price,
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
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(.18),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: T.shadowSmall,
          ),
        ),
      );
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: Container(
          decoration: BoxDecoration(
            color: T.amber.withOpacity(.20),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: T.amber,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: T.shadow,
            ),
            child: const Icon(Icons.flag_rounded, color: T.ink, size: 17),
          ),
        ),
      );
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: T.mapOverlay,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: T.line),
          boxShadow: T.shadowSmall,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: T.success),
            const SizedBox(width: 7),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
