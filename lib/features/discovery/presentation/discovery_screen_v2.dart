import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../config/brand_config.dart';
import '../../../config/design_tokens.dart';
import '../../../services/routing/walking_routing.dart';
import '../../../shared/models/models.dart';
import '../../parking/data/providers.dart';
import '../../search/presentation/search_controller.dart';
import '../../search/presentation/search_sheet_v2.dart';
import 'map_canvas_v2.dart';

class DiscoveryScreenV2 extends ConsumerStatefulWidget {
  const DiscoveryScreenV2({super.key, this.results = false});

  final bool results;

  @override
  ConsumerState<DiscoveryScreenV2> createState() => _DiscoveryScreenV2State();
}

class _DiscoveryScreenV2State extends ConsumerState<DiscoveryScreenV2> {
  final mobileSheet = DraggableScrollableController();
  bool resolving = false;
  String status = '';

  @override
  void dispose() {
    mobileSheet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final state = ref.watch(parkingResultsProvider);
    final spaces = ref.watch(parkingResultsListProvider);
    final selected = ref.watch(selectedParkingIdProvider);

    if (selected == null && spaces.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(selectedParkingIdProvider) == null) {
          ref.read(selectedParkingIdProvider.notifier).state = spaces.first.id;
        }
      });
    }

    return Scaffold(
      backgroundColor: T.porcelain,
      bottomNavigationBar: desktop ? null : const _MobileNavigation(),
      body: SafeArea(
        bottom: false,
        child: desktop
            ? Row(
                children: [
                  SizedBox(
                    width: 480,
                    child: _DesktopPanel(
                      openSearch: _openSearch,
                      openDetails: _openDetails,
                    ),
                  ),
                  Expanded(
                    child: _MapArea(
                      resolving: resolving,
                      state: state,
                      onMapTap: () {},
                    ),
                  ),
                ],
              )
            : _MobileDiscovery(
                controller: mobileSheet,
                resolving: resolving,
                status: status,
                state: state,
                openSearch: _openSearch,
                openDetails: _openDetails,
                collapseSheet: _collapseMobileSheet,
                locate: _locate,
              ),
      ),
    );
  }

  Future<void> _collapseMobileSheet() async {
    if (!mobileSheet.isAttached) return;
    await mobileSheet.animateTo(
      .18,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _locate() async {
    final location = await ref.read(userLocationProvider.notifier).locate();
    if (!mounted) return;
    if (location == null) {
      final error = ref.read(userLocationProvider).asError?.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Standort nicht verfügbar.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aktueller Standort wurde übernommen.')),
    );
    await _collapseMobileSheet();
  }

  Future<void> _openSearch() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: MediaQuery.sizeOf(context).width >= 900 ? .92 : .95,
        child: SearchSheetV2(
          onSubmit: () async {
            Navigator.pop(sheetContext);
            await _resolve();
            if (mounted) context.go('/search');
          },
        ),
      ),
    );
  }

  Future<void> _resolve() async {
    setState(() {
      resolving = true;
      status = 'Verfügbarkeit wird geprüft';
    });
    ref.invalidate(parkingResultsProvider);
    try {
      await ref.read(parkingResultsProvider.future);
      if (!mounted) return;
      setState(() {
        status = '${ref.read(parkingResultsListProvider).length} freie Stellplätze';
      });
      await Future<void>.delayed(const Duration(milliseconds: 350));
    } finally {
      if (mounted) setState(() => resolving = false);
    }
  }

  void _openDetails(String id) => context.go('/parking/$id');
}

class _DesktopPanel extends ConsumerWidget {
  const _DesktopPanel({
    required this.openSearch,
    required this.openDetails,
  });

  final VoidCallback openSearch;
  final ValueChanged<String> openDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(parkingResultsListProvider);
    final state = ref.watch(parkingResultsProvider);
    final query = ref.watch(searchProvider);
    final selected = ref.watch(selectedParkingIdProvider);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: T.porcelain,
        border: Border(right: BorderSide(color: T.line)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
            child: Row(
              children: [
                _BrandMark(),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        BrandConfig.name,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                      Text(
                        BrandConfig.tagline,
                        style: TextStyle(color: T.muted),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Profil',
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(Icons.person_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _SearchCapsule(onTap: openSearch),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _ActiveQuery(query: query),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: _FilterBar(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${spaces.length} freie Stellplätze',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'Auswahl bleibt oben · Route nur aus echten Routing-Daten',
                        style: TextStyle(color: T.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Sortieren',
                  icon: const Icon(Icons.sort_rounded),
                  onSelected: ref.read(searchProvider.notifier).sort,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'Empfohlen', child: Text('Empfohlen')),
                    PopupMenuItem(value: 'Preis', child: Text('Preis')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _RetryState(
                onRetry: () => ref.invalidate(parkingResultsProvider),
              ),
              data: (_) => spaces.isEmpty
                  ? const _EmptyResults()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                      itemCount: spaces.length,
                      itemBuilder: (context, index) {
                        final space = spaces[index];
                        return _ParkingCardV2(
                          space: space,
                          query: query,
                          selected: selected == space.id,
                          onTap: () => ref
                              .read(selectedParkingIdProvider.notifier)
                              .state = space.id,
                          onDetails: () => openDetails(space.id),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDiscovery extends ConsumerWidget {
  const _MobileDiscovery({
    required this.controller,
    required this.resolving,
    required this.status,
    required this.state,
    required this.openSearch,
    required this.openDetails,
    required this.collapseSheet,
    required this.locate,
  });

  final DraggableScrollableController controller;
  final bool resolving;
  final String status;
  final AsyncValue<List<dynamic>> state;
  final VoidCallback openSearch;
  final ValueChanged<String> openDetails;
  final VoidCallback collapseSheet;
  final VoidCallback locate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(parkingResultsListProvider);
    final query = ref.watch(searchProvider);
    final selected = ref.watch(selectedParkingIdProvider);
    final locationState = ref.watch(userLocationProvider);
    return Stack(
      children: [
        Positioned.fill(
          child: _MapArea(
            resolving: resolving,
            state: state,
            onMapTap: collapseSheet,
          ),
        ),
        Positioned(
          left: 14,
          right: 72,
          top: 12,
          child: _SearchCapsule(onTap: openSearch),
        ),
        Positioned(
          top: 13,
          right: 12,
          child: Column(
            children: [
              IconButton.filled(
                tooltip: 'Aktuellen Standort verwenden',
                onPressed: locationState.isLoading ? null : locate,
                icon: locationState.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: T.surface,
                  foregroundColor: T.ink,
                  elevation: 4,
                ),
              ),
              const SizedBox(height: 8),
              IconButton.filled(
                tooltip: 'Profil',
                onPressed: () => context.go('/profile'),
                icon: const Icon(Icons.person_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: T.surface,
                  foregroundColor: T.ink,
                  elevation: 4,
                ),
              ),
            ],
          ),
        ),
        DraggableScrollableSheet(
          controller: controller,
          initialChildSize: .34,
          minChildSize: .18,
          maxChildSize: .84,
          snap: true,
          snapSizes: const [.18, .34, .84],
          builder: (context, scrollController) => DecoratedBox(
            decoration: BoxDecoration(
              color: T.porcelain,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: T.shadowLarge,
            ),
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                14,
                9,
                14,
                MediaQuery.paddingOf(context).bottom + 20,
              ),
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: T.lineStrong,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.local_parking_rounded, color: T.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${spaces.length} freie Stellplätze',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Suche anpassen',
                      onPressed: openSearch,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const _FilterBar(horizontal: true),
                const SizedBox(height: 10),
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.hasError)
                  _RetryState(
                    onRetry: () => ref.invalidate(parkingResultsProvider),
                  )
                else if (spaces.isEmpty)
                  const _EmptyResults()
                else
                  ...spaces.map(
                    (space) => _ParkingCardV2(
                      space: space,
                      query: query,
                      compact: true,
                      selected: selected == space.id,
                      onTap: () => ref
                          .read(selectedParkingIdProvider.notifier)
                          .state = space.id,
                      onDetails: () => openDetails(space.id),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (resolving)
          Positioned(
            top: MediaQuery.sizeOf(context).height * .16,
            left: 24,
            right: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: T.ink,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: T.shadowLarge,
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MapArea extends StatelessWidget {
  const _MapArea({
    required this.resolving,
    required this.state,
    required this.onMapTap,
  });

  final bool resolving;
  final AsyncValue<dynamic> state;
  final VoidCallback onMapTap;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          FreiraumMapV2(resolving: resolving, onMapTap: onMapTap),
          if (state.hasError)
            IgnorePointer(
              child: ColoredBox(
                color: T.porcelain.withOpacity(.72),
                child: const Center(
                  child: Text(
                    'Live-Karte konnte nicht vollständig geladen werden.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
        ],
      );
}

class _ParkingCardV2 extends ConsumerWidget {
  const _ParkingCardV2({
    required this.space,
    required this.query,
    required this.selected,
    required this.onTap,
    required this.onDetails,
    this.compact = false,
  });

  final ParkingSpace space;
  final SearchQuery query;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDetails;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(userLocationProvider).valueOrNull;
    final request = _routeRequest(space, query, location);
    final routeState = request == null
        ? const AsyncValue<WalkingRoute?>.data(null)
        : ref.watch(walkingRouteProvider(request));
    final route = routeState.valueOrNull;
    final currency = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final fits = query.vehicle == null || space.fits(query.vehicle!);
    final total = space.free
        ? 'Kostenlos'
        : '${currency.format(space.total(query.hours))} gesamt';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? T.mintSoft : T.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: T.fast,
            padding: EdgeInsets.all(compact ? 14 : 17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: selected ? T.mint : T.line),
              boxShadow: selected ? T.shadow : T.shadowSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: T.ink,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _accessIcon(space.access),
                        color: T.mint,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            space.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            space.approximate(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: T.muted),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.push_pin_rounded, color: T.success),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (route != null)
                      _Tag(
                        icon: Icons.directions_walk_rounded,
                        text: '${route.durationMinutes} Min. · ${route.distanceLabel}',
                        positive: true,
                      )
                    else if (routeState.isLoading)
                      const _Tag(
                        icon: Icons.route_rounded,
                        text: 'Route wird berechnet',
                      ),
                    _Tag(
                      icon: fits
                          ? Icons.check_circle_rounded
                          : Icons.straighten_rounded,
                      text: fits ? 'Fahrzeug passt' : 'Maße prüfen',
                      positive: fits,
                    ),
                    _Tag(icon: _accessIcon(space.access), text: space.accessLabel()),
                    if (space.free)
                      const _Tag(
                        icon: Icons.volunteer_activism_rounded,
                        text: 'Kostenlos',
                        positive: true,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        total,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: space.free ? T.success : T.ink,
                        ),
                      ),
                    ),
                    const Icon(Icons.star_rounded, color: T.amber, size: 18),
                    Text(
                      space.reviewCount == 0
                          ? 'Neu'
                          : '${space.rating.toStringAsFixed(1)} (${space.reviewCount})',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                if (selected) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.info_rounded),
                    label: const Text('Details ansehen'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  RouteRequest? _routeRequest(
    ParkingSpace space,
    SearchQuery query,
    LatLng? location,
  ) {
    if (query.destination != null) {
      return RouteRequest(
        fromLat: space.lat,
        fromLng: space.lng,
        toLat: query.destination!.lat,
        toLng: query.destination!.lng,
      );
    }
    if (location == null) return null;
    return RouteRequest(
      fromLat: location.latitude,
      fromLng: location.longitude,
      toLat: space.lat,
      toLng: space.lng,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.icon,
    required this.text,
    this.positive = false,
  });

  final IconData icon;
  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: positive ? T.mintSoft : T.porcelain,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: positive ? T.mint : T.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: positive ? T.success : T.muted),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}

class _SearchCapsule extends ConsumerWidget {
  const _SearchCapsule({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchProvider);
    return Material(
      color: T.mapOverlay,
      elevation: 4,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.travel_explore_rounded, color: T.success),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      query.destination?.name ?? 'Wann und wohin?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      query.summary(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: T.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.tune_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveQuery extends StatelessWidget {
  const _ActiveQuery({required this.query});

  final SearchQuery query;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [T.ink, T.inkSoft]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: T.mint),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '${query.summary()} · ${query.durationLabel()}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({this.horizontal = false});

  final bool horizontal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchProvider);
    const filters = [
      ('covered', 'Überdacht', Icons.roofing_rounded),
      ('ev', 'E-Laden', Icons.ev_station_rounded),
      ('accessible', 'Barrierearm', Icons.accessible_forward_rounded),
      ('instant', 'Sofort', Icons.bolt_rounded),
      ('fit', 'Passt', Icons.fact_check_outlined),
      ('free', 'Kostenlos', Icons.money_off_csred_rounded),
    ];
    const access = [
      ('garage', 'Garage', Icons.garage_rounded),
      ('indoor', 'Innen', Icons.meeting_room_rounded),
      ('outdoor', 'Außen', Icons.wb_sunny_rounded),
    ];
    final chips = <Widget>[
      ...filters.map(
        (item) => FilterChip(
          avatar: Icon(item.$3, size: 16),
          label: Text(item.$2),
          selected: query.filters.contains(item.$1),
          onSelected: (_) => ref.read(searchProvider.notifier).toggle(item.$1),
        ),
      ),
      ...access.map(
        (item) => ChoiceChip(
          avatar: Icon(item.$3, size: 16),
          label: Text(item.$2),
          selected: query.filters.contains(item.$1),
          onSelected: (_) => ref
              .read(searchProvider.notifier)
              .exclusiveAccessFilter(item.$1),
        ),
      ),
    ];
    if (!horizontal) return Wrap(spacing: 7, runSpacing: 7, children: chips);
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) => chips[index],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [T.mint, T.success]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: T.shadowSmall,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.local_parking_rounded, color: T.ink),
      );
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation();

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/discover');
            case 1:
              context.go('/bookings');
            case 2:
              context.go('/host');
            case 3:
              context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Entdecken',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number_rounded),
            label: 'Buchungen',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_home_work_outlined),
            selectedIcon: Icon(Icons.add_home_work_rounded),
            label: 'Vermieten',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      );
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42, color: T.muted),
              const SizedBox(height: 10),
              const Text(
                'Stellplätze konnten nicht geladen werden.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: T.muted),
            SizedBox(height: 12),
            Text(
              'Für den gesamten gewählten Zeitraum ist kein passender Stellplatz frei.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}

IconData _accessIcon(AccessType access) => switch (access) {
      AccessType.offen => Icons.wb_sunny_rounded,
      AccessType.schranke => Icons.horizontal_rule_rounded,
      AccessType.tor => Icons.fence_rounded,
      AccessType.tiefgarage => Icons.garage_rounded,
      AccessType.rezeption => Icons.meeting_room_rounded,
    };
