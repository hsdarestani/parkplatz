import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../parking/data/providers.dart';
import '../../parking/presentation/parking_card.dart';
import '../../search/presentation/search_controller.dart';
import '../data/favorites_repository.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(favoritesProvider);
    final spacesState = ref.watch(parkingSpacesProvider);
    final query = ref.watch(searchProvider);

    return FreiraumScaffold(
      title: 'Gemerkte Stellplätze',
      subtitle: 'Deine Favoriten bleiben auf diesem Gerät gespeichert.',
      activePath: '/favorites',
      child: spacesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(parkingSpacesProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Favoriten erneut laden'),
          ),
        ),
        data: (spaces) {
          final favorites = spaces
              .where((space) => favoriteIds.contains(space.id))
              .toList();
          if (favorites.isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: const BoxDecoration(
                          color: T.mintSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bookmark_border_rounded,
                          size: 44,
                          color: T.success,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Noch nichts gemerkt',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Speichere interessante Stellplätze und vergleiche sie später in Ruhe.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: T.muted, height: 1.45),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => context.go('/discover'),
                        icon: const Icon(Icons.explore_outlined),
                        label: const Text('Stellplätze entdecken'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${favorites.length} ${favorites.length == 1 ? 'Stellplatz' : 'Stellplätze'} gespeichert',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...favorites.map(
                        (space) => ParkingCard(
                          s: space,
                          q: query,
                          selected: false,
                          compact: true,
                          onTap: () => context.go('/parking/${space.id}'),
                          onDetails: () => context.go('/parking/${space.id}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
