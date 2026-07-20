import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/models/models.dart';
import '../../marketplace/data/marketplace_repository.dart';
import 'booking_ui_components.dart';

class ParkingPhotoGallery extends ConsumerWidget {
  const ParkingPhotoGallery({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(parkingImagesProvider(spaceId));
    return state.when(
      loading: () => const LinearProgressIndicator(minHeight: 3),
      error: (_, __) => const SizedBox.shrink(),
      data: (images) {
        if (images.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  images[index].imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: T.surfaceRaised,
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ParkingReviewsSection extends ConsumerWidget {
  const ParkingReviewsSection({super.key, required this.space});

  final ParkingSpace space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(parkingReviewsProvider(space.id));
    return BookingSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingSectionTitle(
            icon: Icons.reviews_outlined,
            title: 'Bewertungen',
            subtitle: space.reviewCount == 0
                ? 'Noch keine Bewertung.'
                : '${space.rating.toStringAsFixed(1)} aus ${space.reviewCount} Aufenthalten.',
          ),
          const SizedBox(height: 14),
          state.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text(
              'Bewertungen konnten nicht geladen werden.',
            ),
            data: (reviews) => reviews.isEmpty
                ? const Text(
                    'Bewertungen sind nach bestätigten Aufenthalten verfügbar.',
                    style: TextStyle(color: T.muted),
                  )
                : Column(
                    children: reviews
                        .map(
                          (review) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundImage: review.authorImageUrl == null
                                  ? null
                                  : NetworkImage(review.authorImageUrl!),
                              child: review.authorImageUrl == null
                                  ? const Icon(Icons.person_outline)
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    review.authorName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                ...List.generate(
                                  5,
                                  (index) => Icon(
                                    index < review.rating
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: T.amber,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(review.comment),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
