import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/models/models.dart';
import '../../booking/data/repositories.dart';
import '../data/demo_search_data.dart';
import 'search_controller.dart';

class SearchSheet extends ConsumerWidget {
  final VoidCallback onSubmit;
  const SearchSheet({super.key, required this.onSubmit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(searchProvider);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: T.porcelain,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                color: T.lineStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ankunft vorbereiten',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                ref.watch(appModeProvider) == AppMode.localBeta
                    ? 'Demo: Manuelle Suche funktioniert ohne Standortfreigabe.'
                    : 'Manuelle Suche funktioniert ohne Standortfreigabe.',
                style: const TextStyle(color: T.muted, fontWeight: FontWeight.w600),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _Section(
                    number: '01',
                    title: 'Ziel',
                    child: Column(
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Messe, Bahnhof, Römerberg …',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(color: T.line),
                            ),
                          ),
                          onChanged: (v) {
                            final match = demoDestinations
                                .where(
                                  (d) => d.name.toLowerCase().contains(
                                        v.toLowerCase(),
                                      ),
                                )
                                .firstOrNull;
                            if (match != null)
                              ref
                                  .read(searchProvider.notifier)
                                  .destination(match);
                          },
                        ),
                        const SizedBox(height: 10),
                        ...demoDestinations.take(5).map(
                              (d) => _DestinationRow(
                                destination: d,
                                selected: q.destination?.id == d.id,
                                onTap: () => ref
                                    .read(searchProvider.notifier)
                                    .destination(d),
                              ),
                            ),
                      ],
                    ),
                  ),
                  _Section(
                    number: '02',
                    title: 'Zeit & Dauer',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [1, 2, 4, 6]
                          .map(
                            (h) => ChoiceChip(
                              label: Text(
                                h == 4 ? '4 Std. empfohlen' : '$h Std.',
                              ),
                              selected: q.hours == h,
                              onSelected: (_) =>
                                  ref.read(searchProvider.notifier).duration(h),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  _Section(
                    number: '03',
                    title: 'Fahrzeug',
                    child: Column(
                      children: demoVehicles
                          .map(
                            (v) => _VehicleCard(
                              name: v.name,
                              subtitle:
                                  '${v.plate} · H ${v.height} m · B ${v.width} m · L ${v.length} m',
                              selected: q.vehicle?.id == v.id,
                              onTap: () =>
                                  ref.read(searchProvider.notifier).vehicle(v),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: T.fast,
              width: double.infinity,
              decoration: BoxDecoration(
                boxShadow: q.valid ? T.shadow : null,
                borderRadius: BorderRadius.circular(18),
              ),
              child: FilledButton(
                onPressed: q.valid ? onSubmit : null,
                child: const Text('Stellplätze anzeigen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String number;
  final String title;
  final Widget child;
  const _Section({
    required this.number,
    required this.title,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 18),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: T.surfaceRaised,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: T.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    color: T.mint,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _DestinationRow extends StatelessWidget {
  final Destination destination;
  final bool selected;
  final VoidCallback onTap;
  const _DestinationRow({
    required this.destination,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
        color: selected ? T.mintSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          onTap: onTap,
          dense: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: Icon(
            selected ? Icons.radio_button_checked : Icons.place_outlined,
            color: selected ? T.success : T.muted,
          ),
          title: Text(
            destination.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(destination.district),
          trailing: const Text(
            'wählen',
            style: TextStyle(fontWeight: FontWeight.w800, color: T.muted),
          ),
        ),
      );
}

class _VehicleCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _VehicleCard({
    required this.name,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? T.surfaceSelected : T.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? T.mint : T.line),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_car,
                    color: selected ? T.success : T.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(subtitle, style: const TextStyle(color: T.muted)),
                    ],
                  ),
                ),
                if (selected) const Icon(Icons.check_circle, color: T.success),
              ],
            ),
          ),
        ),
      );
}
