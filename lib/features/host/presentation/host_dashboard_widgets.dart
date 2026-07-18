import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../booking/data/repositories.dart';
import '../data/host_repository.dart';
import 'host_manage_components.dart';

class HostMetricCard extends StatelessWidget {
  const HostMetricCard(this.value, this.label, {super.key, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 230,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
          boxShadow: T.shadowSmall,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: T.mintSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: T.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(label, style: const TextStyle(color: T.muted)),
                ],
              ),
            ),
          ],
        ),
      );
}

class HostSpaceCard extends StatelessWidget {
  const HostSpaceCard({
    super.key,
    required this.space,
    required this.onStatusChanged,
  });

  final HostSpaceRecord space;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
          boxShadow: T.shadowSmall,
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: space.active ? T.mintSoft : T.porcelainDeep,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                space.covered ? Icons.garage_outlined : Icons.local_parking,
                color: space.active ? T.success : T.muted,
              ),
            ),
            SizedBox(
              width: 430,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        space.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Chip(label: Text(space.active ? 'Online' : 'Pausiert')),
                    ],
                  ),
                  Text(
                    '${space.district} · ${space.landmark}',
                    style: const TextStyle(color: T.muted),
                  ),
                  Text(
                    '${euros(space.hourlyPriceCents)} € / Std. · ${space.maxLength.toStringAsFixed(1)} m Länge',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (!space.verified)
                    const Text(
                      'Noch nicht verifiziert',
                      style: TextStyle(color: T.warning),
                    ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => context.go('/host/${space.id}/manage'),
              icon: const Icon(Icons.tune_outlined),
              label: const Text('Verwalten'),
            ),
            OutlinedButton.icon(
              onPressed: space.active
                  ? () => context.go('/parking/${space.id}')
                  : null,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Ansehen'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => onStatusChanged(
                space.active ? 'paused' : 'active',
              ),
              icon: Icon(space.active ? Icons.pause : Icons.play_arrow),
              label: Text(space.active ? 'Pausieren' : 'Aktivieren'),
            ),
          ],
        ),
      );
}

class HostBookingTile extends StatelessWidget {
  const HostBookingTile(this.booking, {super.key});

  final BookingRecord booking;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: T.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_available_outlined, color: T.success),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${hostDateTime(booking.start)} · ${booking.plate}',
                    style: const TextStyle(color: T.muted),
                  ),
                ],
              ),
            ),
            Text(
              '${euros(booking.totalCents)} €',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
}

class HostEmptySpaces extends StatelessWidget {
  const HostEmptySpaces({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
        ),
        child: Column(
          children: [
            const Icon(Icons.add_home_work_outlined, size: 62, color: T.muted),
            const SizedBox(height: 12),
            const Text(
              'Noch kein Stellplatz',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Ersten Stellplatz hinzufügen'),
            ),
          ],
        ),
      );
}
