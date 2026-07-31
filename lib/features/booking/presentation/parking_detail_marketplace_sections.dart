import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                          (review) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
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
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(review.comment),
                                  ),
                                ),
                                if (review.authorId != null)
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _reportReview(
                                          context,
                                          ref,
                                          review,
                                        ),
                                        icon: const Icon(
                                          Icons.flag_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Melden'),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _blockAuthor(
                                          context,
                                          ref,
                                          review,
                                        ),
                                        icon: const Icon(
                                          Icons.block_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Nutzer blockieren'),
                                      ),
                                    ],
                                  ),
                                const Divider(),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => context.go('/trust/support'),
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Anderes Problem melden'),
          ),
        ],
      ),
    );
  }

  Future<void> _reportReview(
    BuildContext context,
    WidgetRef ref,
    ParkingReview review,
  ) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bewertung melden',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: const Text('Unangemessener Inhalt'),
                onTap: () => Navigator.pop(sheetContext, 'inappropriate'),
              ),
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Belästigung oder Missbrauch'),
                onTap: () => Navigator.pop(sheetContext, 'harassment'),
              ),
              ListTile(
                leading: const Icon(Icons.report_gmailerrorred_rounded),
                title: const Text('Spam oder Täuschung'),
                onTap: () => Navigator.pop(sheetContext, 'spam'),
              ),
            ],
          ),
        ),
      ),
    );
    if (reason == null || !context.mounted) return;

    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .reportReview(review.id, reason: reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Danke. Die Meldung wurde an unser Moderationsteam gesendet.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Die Meldung konnte nicht gesendet werden.'),
          ),
        );
      }
    }
  }

  Future<void> _blockAuthor(
    BuildContext context,
    WidgetRef ref,
    ParkingReview review,
  ) async {
    final authorId = review.authorId;
    if (authorId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${review.authorName} blockieren?'),
        content: const Text(
          'Bewertungen dieses Nutzers werden für dich ausgeblendet. Du kannst den Support kontaktieren, wenn du die Blockierung später aufheben möchtest.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Blockieren'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(marketplaceRepositoryProvider).blockUser(authorId);
      ref.invalidate(parkingReviewsProvider(space.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${review.authorName} wurde blockiert.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Der Nutzer konnte nicht blockiert werden.'),
          ),
        );
      }
    }
  }
}
