import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/host_availability_models.dart';
import '../data/host_operations_repository.dart';
import 'host_block_dialog.dart';
import 'host_block_widgets.dart';
import 'host_manage_components.dart';

class HostBlocksEditor extends ConsumerStatefulWidget {
  const HostBlocksEditor({
    super.key,
    required this.spaceId,
    required this.initialBlocks,
  });

  final String spaceId;
  final List<HostAvailabilityBlock> initialBlocks;

  @override
  ConsumerState<HostBlocksEditor> createState() => _HostBlocksEditorState();
}

class _HostBlocksEditorState extends ConsumerState<HostBlocksEditor> {
  late List<HostAvailabilityBlock> blocks = [...widget.initialBlocks]
    ..sort((a, b) => a.start.compareTo(b.start));

  @override
  Widget build(BuildContext context) => HostManageCard(
        title: 'Sperrzeiten',
        subtitle: 'Blockiere Urlaub, Eigennutzung oder Wartungszeiträume.',
        icon: Icons.event_busy_outlined,
        trailing: FilledButton.tonalIcon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Sperrzeit hinzufügen'),
        ),
        child: blocks.isEmpty
            ? const HostEmptyBlocks()
            : Column(
                children: blocks
                    .map(
                      (block) => HostBlockTile(
                        block: block,
                        onDelete: () => _delete(block),
                      ),
                    )
                    .toList(),
              ),
      );

  Future<void> _add() async {
    final draft = await showHostBlockDialog(context);
    if (draft == null) return;
    try {
      final saved = await ref.read(hostOperationsRepositoryProvider).addBlock(
            widget.spaceId,
            draft.start,
            draft.end,
            draft.reason.isEmpty ? null : draft.reason,
          );
      if (mounted) {
        setState(() {
          blocks = [...blocks, saved]
            ..sort((a, b) => a.start.compareTo(b.start));
        });
        _message('Sperrzeit wurde hinzugefügt.');
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    }
  }

  Future<void> _delete(HostAvailabilityBlock block) async {
    try {
      await ref
          .read(hostOperationsRepositoryProvider)
          .deleteBlock(widget.spaceId, block.id);
      if (mounted) {
        setState(() {
          blocks = blocks.where((value) => value.id != block.id).toList();
        });
        _message('Sperrzeit wurde entfernt.');
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
