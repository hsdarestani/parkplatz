import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_motion.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../parking/data/providers.dart';
import '../data/host_availability_models.dart';
import '../data/host_operations_repository.dart';
import '../data/host_repository.dart';
import 'host_blocks_editor.dart';
import 'host_details_editor.dart';
import 'host_manage_components.dart';
import 'host_schedule_editor.dart';

class HostManageScreen extends ConsumerStatefulWidget {
  const HostManageScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<HostManageScreen> createState() => _HostManageScreenState();
}

class _HostManageScreenState extends ConsumerState<HostManageScreen> {
  late Future<_ManageData> future = _load();
  HostSpaceRecord? currentSpace;

  Future<_ManageData> _load() async {
    final spaces = await ref.read(hostRepositoryProvider).spaces();
    final space = spaces.where((value) => value.id == widget.id).firstOrNull;
    if (space == null) throw StateError('Stellplatz nicht gefunden.');
    final availability =
        await ref.read(hostOperationsRepositoryProvider).availability(widget.id);
    return _ManageData(space, availability);
  }

  void _reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Stellplatz verwalten',
        subtitle: 'Angebot, Wochenplan, Preise und Sperrzeiten.',
        activePath: '/host',
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go('/parking/${widget.id}'),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Öffentliche Ansicht'),
          ),
        ],
        child: FutureBuilder<_ManageData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return HostErrorState(
                message: snapshot.error.toString(),
                onRetry: _reload,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            currentSpace ??= snapshot.data!.space;
            return _content(snapshot.data!);
          },
        ),
      );

  Widget _content(_ManageData data) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MotionReveal(child: _hero(currentSpace!, data.availability)),
                  const SizedBox(height: 20),
                  MotionReveal(
                    delay: const Duration(milliseconds: 70),
                    child: HostDetailsEditor(
                      space: currentSpace!,
                      onSaved: (space) => setState(() => currentSpace = space),
                    ),
                  ),
                  const SizedBox(height: 20),
                  MotionReveal(
                    delay: const Duration(milliseconds: 120),
                    child: HostScheduleEditor(
                      spaceId: widget.id,
                      basePriceCents: currentSpace!.hourlyPriceCents,
                      initialRules: data.availability.rules,
                    ),
                  ),
                  const SizedBox(height: 20),
                  MotionReveal(
                    delay: const Duration(milliseconds: 170),
                    child: HostBlocksEditor(
                      spaceId: widget.id,
                      initialBlocks: data.availability.blocks,
                    ),
                  ),
                  const SizedBox(height: 20),
                  MotionReveal(
                    delay: const Duration(milliseconds: 220),
                    child: _dangerCard(),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _hero(
    HostSpaceRecord space,
    HostAvailabilityConfig availability,
  ) =>
      Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [T.ink, T.inkSoft],
          ),
          borderRadius: BorderRadius.circular(T.radiusSpacious),
          boxShadow: T.shadow,
        ),
        child: Wrap(
          spacing: 22,
          runSpacing: 18,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: T.mint.withOpacity(.16),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                color: T.mint,
                size: 34,
              ),
            ),
            SizedBox(
              width: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    space.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${space.district} · ${space.landmark}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      HostDarkPill(
                        icon: space.active
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                        text: space.active ? 'Online' : 'Pausiert',
                      ),
                      HostDarkPill(
                        icon: Icons.euro,
                        text: '${euros(space.hourlyPriceCents)} € Basispreis',
                      ),
                      HostDarkPill(
                        icon: Icons.event_available_outlined,
                        text:
                            '${availability.rules.where((rule) => rule.active).length} aktive Tage',
                      ),
                      HostDarkPill(
                        icon: Icons.event_busy_outlined,
                        text: '${availability.blocks.length} Sperrzeiten',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _dangerCard() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4F2),
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: const Color(0xFFF3B8AE)),
        ),
        child: Wrap(
          spacing: 20,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.delete_outline, color: Color(0xFFB23A2B), size: 32),
            const SizedBox(
              width: 700,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stellplatz löschen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF8C2E22),
                    ),
                  ),
                  Text(
                    'Der Eintrag verschwindet aus Suche und Dashboard. Aktive Buchungen müssen zuerst beendet sein.',
                    style: TextStyle(color: Color(0xFF8C2E22)),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _archive,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Dauerhaft entfernen'),
            ),
          ],
        ),
      );

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stellplatz wirklich entfernen?'),
        content: const Text(
          'Der Stellplatz verschwindet dauerhaft aus der Suche. Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(hostOperationsRepositoryProvider).archive(widget.id);
      ref.invalidate(parkingSpacesProvider);
      if (mounted) context.go('/host');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}

class _ManageData {
  const _ManageData(this.space, this.availability);

  final HostSpaceRecord space;
  final HostAvailabilityConfig availability;
}
