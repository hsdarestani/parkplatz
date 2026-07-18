import 'package:flutter/material.dart';

import '../data/host_availability_models.dart';
import 'host_manage_components.dart';

class HostBlockTile extends StatelessWidget {
  const HostBlockTile({
    super.key,
    required this.block,
    required this.onDelete,
  });

  final HostAvailabilityBlock block;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_busy_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${hostDateTime(block.start)} – ${hostDateTime(block.end)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    block.reason?.isNotEmpty == true
                        ? block.reason!
                        : 'Ohne Begründung',
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: 'Sperrzeit entfernen',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      );
}

class HostEmptyBlocks extends StatelessWidget {
  const HostEmptyBlocks({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: const Row(
          children: [
            Icon(Icons.event_available_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Keine Sperrzeiten. Dein Wochenplan gilt ohne Ausnahmen.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
}
