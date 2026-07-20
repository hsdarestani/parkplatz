import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/brand_config.dart';
import '../../../config/design_tokens.dart';
import '../../booking/data/repositories.dart';
import '../../parking/data/providers.dart';
import '../../parking/presentation/parking_card.dart';
import '../../search/presentation/search_controller.dart';
import '../../search/presentation/search_sheet.dart';
import 'map_canvas.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key, this.results = false});

  final bool results;

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  bool resolving = false;
  String status = '';

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
                    width: 470,
                    child: _DesktopResultsPanel(
                      openSearch: _openSearch,
                      openDetails: _openDetails,
                    ),
                  ),
                  Expanded(
                    child: _MapArea(
                      resolving: resolving,
                      status: status,
                      spacesState: state,
                    ),
                  ),
                ],
              )
            : _MobileDiscovery(
                resolving: resolving,
                status: status,
                spacesState: state,
                openSearch: _openSearch,
                openDetails: _openDetails,
              ),
      ),
    );
  }

  Future<void> _openSearch() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: MediaQuery.sizeOf(context).width >= 900 ? .90 : .94,
        child: SearchSheet(
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
      await Future<void>.delayed(const Duration(milliseconds: 500));
    } finally {
      if (mounted) setState(() => resolving = false);
    }
  }

  void _openDetails(String parkingId) => context.go('/parking/$parkingId');
}

class _DesktopResultsPanel extends ConsumerWidget {
  const _DesktopResultsPanel({
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: T.ink,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'F',
                    style: TextStyle(
                      color: T.mint,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        BrandConfig.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                      Text(
                        BrandConfig.tagline,
                        style: TextStyle(
                          color: T.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Profil',
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(Icons.account_circle_outlined),
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
            padding: const EdgeInsets.fromLTRB(22, 15, 22, 8),
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
                        'Auswahl bleibt oben · Adresse nach Bestätigung',
                        style: TextStyle(
                          color: T.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
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
                    PopupMenuItem(value: 'Entfernung', child: Text('Entfernung')),
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
                        return ParkingCard(
                          s: space,
                          q: query,
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
    required this.resolving,
    required this.status,
    required this.spacesState,
    required this.openSearch,
    required this.openDetails,
  });

  final bool resolving;
  final String status;
  final AsyncValue<List<dynamic>> spacesState;
  final VoidCallback openSearch;
  final ValueChanged<String> openDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(parkingResultsListProvider);
    final query = ref.watch(searchProvider);
    final selected = ref.watch(selectedParkingIdProvider);
    return Stack(
      children: [
        Positioned.fill(
          child: _MapArea(
            resolving: resolving,
            status: status,
            spacesState: spacesState,
          ),
        ),
        Positioned(
          left: 14,
          right: 70,
          top: 12,
          child: _SearchCapsule(onTap: openSearch),
        ),
        Positioned(
          right: 12,
          top: 14,
          child: Column(
            children: [
              _RoundMapButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Standort',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Standort wird nur nach Freigabe verwendet.'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _RoundMapButton(
                icon: Icons.person_outline_rounded,
                tooltip: 'Profil',
                onTap: () => context.go('/profile'),
              ),
            ],
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: .34,
          minChildSize: .18,
          maxChildSize: .84,
          snap: true,
          snapSizes: const [.18, .34, .84],
          builder: (context, controller) => DecoratedBox(
            decoration: BoxDecoration(
              color: T.porcelain,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: T.shadowLarge,
            ),
            child: ListView(
              controller: controller,
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
                    Expanded(
                      child: Text(
                        '${spaces.length} freie Stellplätze',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Suche anpassen',
                      onPressed: openSearch,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const _FilterBar(horizontal: true),
                const SizedBox(height: 10),
                if (spacesState.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (spacesState.hasError)
                  _RetryState(
                    onRetry: () => ref.invalidate(parkingResultsProvider),
                  )
                else if (spaces.isEmpty)
                  const _EmptyResults()
                else
                  ...spaces.map(
                    (space) => ParkingCard(
                      s: space,
                      q: query,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
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
    required this.status,
    required this.spacesState,
  });

  final bool resolving;
  final String status;
  final AsyncValue<dynamic> spacesState;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          FreiraumMap(resolving: resolving),
          if (spacesState.hasError)
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

class _SearchCapsule extends ConsumerWidget {
  const _SearchCapsule({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchProvider);
    return Material(
      color: T.mapOverlay,
      elevation: 4,
      shadowColor: T.ink.withOpacity(.12),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              const Icon(Icons.search_rounded),
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
                      style: const TextStyle(
                        color: T.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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

  final dynamic query;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: T.ink,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: T.mint, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                query.summary(),
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
      ('covered', 'Überdacht', Icons.roofing_outlined),
      ('ev', 'E-Laden', Icons.ev_station_outlined),
      ('accessible', 'Barrierearm', Icons.accessible_outlined),
      ('instant', 'Sofort', Icons.bolt_outlined),
      ('fit', 'Passt', Icons.straighten_outlined),
      ('free', 'Kostenlos', Icons.money_off_csred_outlined),
    ];
    const access = [
      ('garage', 'Garage', Icons.garage_outlined),
      ('indoor', 'Innen', Icons.meeting_room_outlined),
      ('outdoor', 'Außen', Icons.wb_sunny_outlined),
    ];

    final chips = <Widget>[
      ...filters.map(
        (item) => FilterChip(
          avatar: Icon(item.$3, size: 16),
          label: Text(item.$2),
          selected: query.filters.contains(item.$1),
          onSelected: (_) =>
              ref.read(searchProvider.notifier).toggle(item.$1),
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

    if (!horizontal) {
      return Wrap(spacing: 7, runSpacing: 7, children: chips);
    }
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

class _RoundMapButton extends StatelessWidget {
  const _RoundMapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton.filled(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: T.surface,
          foregroundColor: T.ink,
          elevation: 4,
          shadowColor: T.ink.withOpacity(.18),
        ),
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
              const Icon(Icons.cloud_off_outlined, size: 42, color: T.muted),
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
            Icon(Icons.local_parking_outlined, size: 48, color: T.muted),
            SizedBox(height: 12),
            Text(
              'Für den gewählten Zeitraum ist kein passender Stellplatz frei.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}