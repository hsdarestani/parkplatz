import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/illustration.dart';
import '../../booking/data/repositories.dart';
import '../../favorites/data/favorites_repository.dart';

class ParkingCard extends ConsumerWidget {
  const ParkingCard({
    super.key,
    required this.s,
    required this.q,
    required this.selected,
    required this.onTap,
    this.onDetails,
    this.compact = false,
  });

  final ParkingSpace s;
  final SearchQuery q;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDetails;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = ref.watch(favoritesProvider).contains(s.id);
    final currency = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final fits = q.vehicle == null || s.fits(q.vehicle!);

    Future<void> toggle() async {
      await ref.read(favoritesProvider.notifier).toggle(s.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(favorite ? 'Favorit entfernt.' : 'Favorit gespeichert.'),
            action: favorite
                ? null
                : SnackBarAction(
                    label: 'Öffnen',
                    onPressed: () => context.go('/favorites'),
                  ),
          ),
        );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: selected ? T.surfaceSelected : T.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.radius),
        side: BorderSide(
          color: selected ? T.mint : T.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(T.radius),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ParkingIllustration(
                    s.visual,
                    width: compact ? 94 : 112,
                    height: compact ? 74 : 86,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: favorite ? 'Entfernen' : 'Merken',
                              onPressed: toggle,
                              icon: Icon(
                                favorite
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_outline_rounded,
                                color: favorite ? T.success : T.muted,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          s.approximate(),
                          style: const TextStyle(color: T.muted),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _Tag('${s.walkingMinutes} Min.'),
                            _Tag(fits ? 'Fahrzeug passt' : 'Maße prüfen'),
                            _Tag(s.accessLabel()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${currency.format(s.total(q.hours))} gesamt',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.star_rounded, color: T.amber, size: 18),
                  Text(
                    '${s.rating.toStringAsFixed(1)} (${s.reviewCount})',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              if (selected) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: onDetails,
                        child: const Text('Details ansehen'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: toggle,
                      icon: Icon(
                        favorite
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                      ),
                      label: Text(favorite ? 'Gemerkt' : 'Merken'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: T.porcelain,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: T.line),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      );
}
