import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/brand_config.dart';
import '../../../config/design_tokens.dart';
import '../../parking/data/providers.dart';
import '../../parking/presentation/parking_card.dart';
import '../../search/presentation/search_controller.dart';
import '../../search/presentation/search_sheet.dart';
import 'map_canvas.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  final bool results;
  const DiscoveryScreen({super.key, this.results = false});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  bool resolving = false;
  String status = '';

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width > T.desktop;
    final query = ref.watch(searchProvider);
    final mode = ref.watch(appModeProvider);
    final spacesState = ref.watch(parkingResultsProvider);
    final results = ref.watch(parkingResultsListProvider);
    final selected =
        ref.watch(selectedParkingIdProvider) ?? results.firstOrNull?.id;
    if (ref.watch(selectedParkingIdProvider) == null && results.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(selectedParkingIdProvider.notifier).state = selected,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          if (desktop)
            _DesktopRail(onPreview: (title) => title == 'Buchungen'
                ? context.go('/bookings')
                : _preview(context, title)),
          if (desktop)
            _Panel(
              openSearch: () => _openSearch(context),
              onDetails: (spaceTitle) => _details(context, spaceTitle),
            ),
          Expanded(
            child: Stack(
              children: [
                FreiraumMap(resolving: resolving),
                if (!desktop)
                  _MobileTopBar(openSearch: () => _openSearch(context)),
                Positioned(
                  right: 16,
                  top: MediaQuery.paddingOf(context).top + (desktop ? 18 : 88),
                  child: _MapControls(
                    onProfile: () => _profile(context),
                    onLocation: () => _snack(
                      context,
                      mode == AppMode.localBeta
                          ? 'Demo-Standort Frankfurt verwendet. Keine Hintergrund-Ortung.'
                          : 'Standort wird nur auf Anfrage verwendet. Keine Hintergrund-Ortung.',
                    ),
                  ),
                ),
                if (!desktop)
                  _MobileSheet(
                    onDetails: (spaceTitle) => _details(context, spaceTitle),
                  ),
                if (spacesState.isLoading)
                  const Positioned.fill(child: _DataState(message: 'Live-Stellplätze werden geladen …', loading: true)),
                if (spacesState.hasError)
                  Positioned.fill(child: _DataState(message: 'Stellplätze konnten nicht geladen werden.', onRetry: () => ref.invalidate(parkingSpacesProvider))),
                if (spacesState.hasValue && results.isEmpty)
                  const Positioned.fill(child: _DataState(message: 'Für diese Suche sind keine Stellplätze verfügbar.')),
                if (resolving) _ResolutionToast(status: status),
                if (desktop)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 18,
                    left: 20,
                    child: _MapContext(
                      destination: query.destination?.name ?? 'Frankfurt',
                      text: mode == AppMode.localBeta
                          ? '${results.length} passende Stellplätze · Demo'
                          : '${results.length} passende Stellplätze · Live',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSearch(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: MediaQuery.sizeOf(context).width > T.desktop ? .88 : .92,
        child: SearchSheet(
          onSubmit: () async {
            Navigator.pop(context);
            await _resolve();
            if (mounted && context.mounted) {
              context.go('/search');
            }
          },
        ),
      ),
    );
  }

  Future<void> _resolve() async {
    final reduced = MediaQuery.disableAnimationsOf(context);
    setState(() {
      resolving = true;
      status = 'Verfügbarkeit wird geprüft';
    });
    await Future.delayed(
      reduced ? Duration.zero : const Duration(milliseconds: 420),
    );
    setState(
      () => status =
          '${ref.read(parkingResultsListProvider).length} passende Stellplätze',
    );
    await Future.delayed(
      reduced ? Duration.zero : const Duration(milliseconds: 420),
    );
    final first = ref.read(parkingResultsListProvider).firstOrNull;
    if (first != null)
      ref.read(selectedParkingIdProvider.notifier).state = first.id;
    setState(() => status = 'Deine Ankunft ist vorbereitet');
    await Future.delayed(
      reduced ? Duration.zero : const Duration(milliseconds: 520),
    );
    if (mounted) setState(() => resolving = false);
  }

  void _details(
    BuildContext context,
    String title,
  ) {
    final space = ref.read(parkingResultsListProvider).firstWhere(
          (item) => item.title == title,
          orElse: () => ref.read(parkingResultsListProvider).first,
        );
    context.go('/parking/${space.id}');
  }

  void _preview(BuildContext context, String title) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Diese Route wird in einer nächsten Iteration voll ausgebaut.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Verstanden'),
              ),
            ],
          ),
        ),
      );
  void _snack(BuildContext context, String message) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
  void _profile(BuildContext context) => _preview(context, 'Profil');
}

class _Panel extends ConsumerWidget {
  final VoidCallback openSearch;
  final void Function(String) onDetails;
  const _Panel({required this.openSearch, required this.onDetails});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(searchProvider);
    final results = ref.watch(parkingResultsListProvider);
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
          _ContextCard(summary: q.summary()),
          const SizedBox(height: 14),
          _Filters(),
          const SizedBox(height: 12),
          Text(
            '${results.length} passende Stellplätze',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          Text(
            ref.watch(appModeProvider) == AppMode.localBeta
                ? 'Demo-Daten · genaue Zufahrt erst nach Buchung'
                : 'Live-Daten · genaue Zufahrt erst nach Buchung',
            style: const TextStyle(color: T.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: results.isEmpty
                ? const _EmptyResults()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 18),
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final space = results[i];
                      return ParkingCard(
                        s: space,
                        q: q,
                        selected:
                            ref.watch(selectedParkingIdProvider) == space.id,
                        onTap: () => ref
                            .read(selectedParkingIdProvider.notifier)
                            .state = space.id,
                        onDetails: () => onDetails(space.title),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MobileSheet extends ConsumerWidget {
  final void Function(String) onDetails;
  const _MobileSheet({required this.onDetails});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(parkingResultsListProvider);
    final q = ref.watch(searchProvider);
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${results.length} passende Stellplätze',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (ref.watch(appModeProvider) == AppMode.localBeta)
                  const _DemoBadge(),
              ],
            ),
            const SizedBox(height: 8),
            _Filters(mobile: true),
            const SizedBox(height: 8),
            if (results.isEmpty)
              const _EmptyResults()
            else
              ...results.map(
                (space) => ParkingCard(
                  s: space,
                  q: q,
                  compact: true,
                  selected: ref.watch(selectedParkingIdProvider) == space.id,
                  onTap: () => ref
                      .read(selectedParkingIdProvider.notifier)
                      .state = space.id,
                  onDetails: () => onDetails(space.title),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  final bool mobile;
  const _Filters({this.mobile = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(searchProvider);
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
      children: [
        DropdownButton<String>(
          value: q.sort,
          borderRadius: BorderRadius.circular(16),
          items: [
            'Empfohlen',
            'Preis',
            'Fußweg',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => ref.read(searchProvider.notifier).sort(v!),
        ),
        ...filters.entries.map(
          (e) => FilterChip(
            label: Text(e.value),
            selected: q.filters.contains(e.key),
            onSelected: (_) => ref.read(searchProvider.notifier).toggle(e.key),
          ),
        ),
      ],
    );
  }
}

class _MobileTopBar extends ConsumerWidget {
  final VoidCallback openSearch;
  const _MobileTopBar({required this.openSearch});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Positioned(
        top: MediaQuery.paddingOf(context).top + 12,
        left: 14,
        right: 76,
        child: _SearchCapsule(onTap: openSearch),
      );
}

class _SearchCapsule extends ConsumerWidget {
  final VoidCallback onTap;
  const _SearchCapsule({required this.onTap});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(searchProvider);
    return Semantics(
      button: true,
      label: 'Suche öffnen',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: T.mapOverlay,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: T.line),
            boxShadow: T.shadow,
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: T.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.destination?.name ?? 'Wohin möchtest du?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      q.destination == null
                          ? 'Heute · 18:00–22:00 · VW Golf'
                          : q.summary(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: T.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopRail extends StatelessWidget {
  final void Function(String) onPreview;
  const _DesktopRail({required this.onPreview});
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
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
            const Spacer(),
            ...['Entdecken', 'Buchungen', 'Vermieten', 'Profil'].map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: IconButton(
                  onPressed: t == 'Entdecken' ? null : () => onPreview(t),
                  tooltip: t,
                  icon: Icon(
                    t == 'Entdecken'
                        ? Icons.explore
                        : t == 'Buchungen'
                            ? Icons.confirmation_number_outlined
                            : t == 'Vermieten'
                                ? Icons.add_home_work_outlined
                                : Icons.person_outline,
                  ),
                  color: t == 'Entdecken' ? T.mint : Colors.white,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      );
}

class _MapControls extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onLocation;
  const _MapControls({required this.onProfile, required this.onLocation});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          _Round(
            icon: Icons.my_location,
            label: 'Standort verwenden',
            onTap: onLocation,
          ),
          _Round(icon: Icons.person, label: 'Profil öffnen', onTap: onProfile),
        ],
      );
}

class _Round extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Round({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Semantics(
          label: label,
          button: true,
          child: IconButton.filled(
            onPressed: onTap,
            icon: Icon(icon),
            style: IconButton.styleFrom(
              backgroundColor: T.surface,
              foregroundColor: T.ink,
            ),
          ),
        ),
      );
}

class _ContextCard extends StatelessWidget {
  final String summary;
  const _ContextCard({required this.summary});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: T.ink,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          summary,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      );
}

class _MapContext extends StatelessWidget {
  final String destination, text;
  const _MapContext({required this.destination, required this.text});
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
            Text(destination,
                style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(
              text,
              style:
                  const TextStyle(color: T.muted, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

class _ResolutionToast extends StatelessWidget {
  final String status;
  const _ResolutionToast({required this.status});
  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        right: 0,
        top: MediaQuery.sizeOf(context).height * .18,
        child: Center(
          child: AnimatedContainer(
            duration: T.fast,
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

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: T.amberSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child:
            const Text('Demo', style: TextStyle(fontWeight: FontWeight.w900)),
      );
}

class _EmptyResults extends ConsumerWidget {
  const _EmptyResults();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Keine Stellplätze mit diesen Filtern.',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  for (final f in [...ref.read(searchProvider).filters]) {
                    ref.read(searchProvider.notifier).toggle(f);
                  }
                },
                child: const Text('Filter zurücksetzen'),
              ),
            ],
          ),
        ),
      );
}

class _DataState extends StatelessWidget {
  const _DataState({required this.message, this.loading = false, this.onRetry});
  final String message; final bool loading; final VoidCallback? onRetry;
  @override Widget build(BuildContext context) => ColoredBox(
    color: T.porcelain.withOpacity(.94),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (loading) const CircularProgressIndicator(),
      if (loading) const SizedBox(height: 16),
      Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
      if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Erneut versuchen')),
    ])),
  );
}
