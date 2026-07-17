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
    final desktop = MediaQuery.sizeOf(context).width > T.desktop;
    final mode = ref.watch(appModeProvider);
    final spacesState = ref.watch(parkingResultsProvider);
    final spaces = ref.watch(parkingResultsListProvider);
    final selected = ref.watch(selectedParkingIdProvider);

    if (selected == null && spaces.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(selectedParkingIdProvider.notifier).state = spaces.first.id;
        }
      });
    }

    return Scaffold(
      body: Row(
        children: [
          if (desktop) const _DesktopRail(),
          if (desktop)
            _DesktopPanel(
              openSearch: _openSearch,
              openDetails: _openDetails,
            ),
          Expanded(
            child: Stack(
              children: [
                FreiraumMap(resolving: resolving),
                if (!desktop)
                  _MobileSearchBar(openSearch: _openSearch),
                Positioned(
                  right: 16,
                  top: MediaQuery.paddingOf(context).top + (desktop ? 18 : 88),
                  child: _MapActions(
                    onProfile: () => context.go('/profile'),
                    onLocation: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          mode == AppMode.localBeta
                              ? 'Demo-Standort Frankfurt wird verwendet.'
                              : 'Standort wird nur auf Anfrage verwendet.',
                        ),
                      ),
                    ),
                  ),
                ),
                if (!desktop)
                  _MobileResults(
                    openDetails: _openDetails,
                  ),
                if (desktop)
                  Positioned(
                    left: 20,
                    top: MediaQuery.paddingOf(context).top + 18,
                    child: _MapContext(
                      resultCount: spaces.length,
                      live: mode != AppMode.localBeta,
                    ),
                  ),
                if (spacesState.isLoading)
                  const Positioned.fill(
                    child: _DataOverlay(
                      message: 'Live-Stellplätze werden geladen …',
                      loading: true,
                    ),
                  ),
                if (spacesState.hasError)
                  Positioned.fill(
                    child: _DataOverlay(
                      message: 'Stellplätze konnten nicht geladen werden.',
                      onRetry: () => ref.invalidate(parkingSpacesProvider),
                    ),
                  ),
                if (spacesState.hasValue && spaces.isEmpty)
                  const Positioned.fill(
                    child: _DataOverlay(
                      message: 'Für diese Suche sind keine Stellplätze verfügbar.',
                    ),
                  ),
                if (resolving) _ResolutionToast(status: status),
              ],
            ),
          ),
        ],
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
        heightFactor: MediaQuery.sizeOf(context).width > T.desktop ? .88 : .92,
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
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    setState(() {
      status = '${ref.read(parkingResultsListProvider).length} passende Stellplätze';
    });
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    setState(() {
      status = 'Deine Ankunft ist vorbereitet';
    });
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (mounted) setState(() => resolving = false);
  }

  void _openDetails(String parkingId) => context.go('/parking/$parkingId');
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
    final query = ref.watch(searchProvider);
    final selected = ref.watch(selectedParkingIdProvider);
    final mode = ref.watch(appModeProvider);

    return Container(
      width: T.desktopPanel,
      color: T.porcelain,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 18,
        20,
        18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            BrandConfig.name,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const Text(
            BrandConfig.tagline,
            style: TextStyle(color: T.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          _SearchCapsule(onTap: openSearch),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.ink,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              query.summary(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _Filters(),
          const SizedBox(height: 12),
          Text(
            '${spaces.length} passende Stellplätze',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(
            mode == AppMode.localBeta
                ? 'Demo-Daten · Adresse nach Buchung'
                : 'Live-Daten · Adresse nach Buchung',
            style: const TextStyle(color: T.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
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
        ],
      ),
    );
  }
}

class _MobileResults extends ConsumerWidget {
  const _MobileResults({required this.openDetails});

  final ValueChanged<String> openDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(parkingResultsListProvider);
    final query = ref.watch(searchProvider);
    final selected = ref.watch(selectedParkingIdProvider);

    return DraggableScrollableSheet(
      initialChildSize: .34,
      minChildSize: .22,
      maxChildSize: .86,
      builder: (context, controller) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        decoration: BoxDecoration(
          color: T.porcelain,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: T.shadowLarge,
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 18,
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
            Text(
              '${spaces.length} passende Stellplätze',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const _Filters(),
            const SizedBox(height: 8),
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
    );
  }
}

class _SearchCapsule extends ConsumerWidget {
  const _SearchCapsule({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchProvider);
    return Material(
      color: T.mapOverlay,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: T.line),
            boxShadow: T.shadow,
          ),
          child: Row(
            children: [
              const Icon(Icons.search),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      query.destination?.name ?? 'Wohin möchtest du?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      query.destination == null
                          ? 'Heute · 18:00–22:00 · VW Golf'
                          : query.summary(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: T.muted,
                        fontSize: 12,
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

class _MobileSearchBar extends StatelessWidget {
  const _MobileSearchBar({required this.openSearch});

  final VoidCallback openSearch;

  @override
  Widget build(BuildContext context) => Positioned(
        top: MediaQuery.paddingOf(context).top + 12,
        left: 14,
        right: 76,
        child: _SearchCapsule(onTap: openSearch),
      );
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail();

  @override
  Widget build(BuildContext context) => Container(
        width: 76,
        color: T.ink,
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 18,
          bottom: 18,
        ),
        child: Column(
          children: [
            const Text(
              'F',
              style: TextStyle(
                color: T.mint,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            _RailButton(
              icon: Icons.explore,
              label: 'Entdecken',
              selected: true,
              onTap: () {},
            ),
            _RailButton(
              icon: Icons.confirmation_number_outlined,
              label: 'Buchungen',
              onTap: () => context.go('/bookings'),
            ),
            _RailButton(
              icon: Icons.add_home_work_outlined,
              label: 'Vermieten',
              onTap: () => context.go('/host'),
            ),
            _RailButton(
              icon: Icons.person_outline,
              label: 'Profil',
              onTap: () => context.go('/profile'),
            ),
            const Spacer(),
          ],
        ),
      );
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: IconButton(
          tooltip: label,
          onPressed: onTap,
          icon: Icon(icon),
          color: selected ? T.mint : Colors.white,
        ),
      );
}

class _MapActions extends StatelessWidget {
  const _MapActions({required this.onProfile, required this.onLocation});

  final VoidCallback onProfile;
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          IconButton.filled(
            tooltip: 'Standort verwenden',
            onPressed: onLocation,
            icon: const Icon(Icons.my_location),
            style: IconButton.styleFrom(
              backgroundColor: T.surface,
              foregroundColor: T.ink,
            ),
          ),
          const SizedBox(height: 8),
          IconButton.filled(
            tooltip: 'Profil öffnen',
            onPressed: onProfile,
            icon: const Icon(Icons.person),
            style: IconButton.styleFrom(
              backgroundColor: T.surface,
              foregroundColor: T.ink,
            ),
          ),
        ],
      );
}

class _Filters extends ConsumerWidget {
  const _Filters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchProvider);
    const filters = {
      'covered': 'Überdacht',
      'ev': 'E-Laden',
      'accessible': 'Barrierearm',
      'instant': 'Sofortbuchung',
      'fit': 'Fahrzeug passt',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.entries
          .map(
            (entry) => FilterChip(
              label: Text(entry.value),
              selected: query.filters.contains(entry.key),
              onSelected: (_) =>
                  ref.read(searchProvider.notifier).toggle(entry.key),
            ),
          )
          .toList(),
    );
  }
}

class _MapContext extends StatelessWidget {
  const _MapContext({required this.resultCount, required this.live});

  final int resultCount;
  final bool live;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: T.mapOverlay,
          borderRadius: BorderRadius.circular(20),
          boxShadow: T.shadowSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Frankfurt', style: TextStyle(fontWeight: FontWeight.w900)),
            Text(
              '$resultCount passende Stellplätze · ${live ? 'Live' : 'Demo'}',
              style: const TextStyle(color: T.muted, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

class _DataOverlay extends StatelessWidget {
  const _DataOverlay({
    required this.message,
    this.loading = false,
    this.onRetry,
  });

  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: T.porcelain.withOpacity(.94),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) const CircularProgressIndicator(),
              if (loading) const SizedBox(height: 16),
              Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Erneut versuchen'),
                ),
            ],
          ),
        ),
      );
}

class _ResolutionToast extends StatelessWidget {
  const _ResolutionToast({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        right: 0,
        top: MediaQuery.sizeOf(context).height * .18,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
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
      );
}
