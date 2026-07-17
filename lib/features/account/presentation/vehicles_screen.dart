import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../booking/data/repositories.dart';
import '../../parking/data/providers.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  late Future<List<VehicleRecord>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<VehicleRecord>> _load() =>
      ref.read(vehicleRepositoryProvider).all();

  void reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Meine Fahrzeuge',
        subtitle: 'Kennzeichen und Maße für passende Stellplätze.',
        activePath: '/profile',
        actions: [
          FilledButton.icon(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Hinzufügen'),
          ),
        ],
        child: FutureBuilder<List<VehicleRecord>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: reload,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final vehicles = snapshot.data!;
            if (vehicles.isEmpty) {
              return _EmptyState(onAdd: () => _edit());
            }
            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: vehicles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) => _VehicleCard(
                vehicle: vehicles[index],
                onEdit: () => _edit(vehicles[index]),
                onDelete: () => _delete(vehicles[index]),
              ),
            );
          },
        ),
      );

  Future<void> _edit([VehicleRecord? vehicle]) async {
    final name = TextEditingController(text: vehicle?.name ?? '');
    final plate = TextEditingController(text: vehicle?.plate ?? '');
    final height = TextEditingController(
      text: vehicle?.height.toStringAsFixed(2) ?? '',
    );
    final width = TextEditingController(
      text: vehicle?.width.toStringAsFixed(2) ?? '',
    );
    final length = TextEditingController(
      text: vehicle?.length.toStringAsFixed(2) ?? '',
    );
    var isDefault = vehicle?.isDefault ?? false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(vehicle == null ? 'Fahrzeug hinzufügen' : 'Fahrzeug bearbeiten'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Bezeichnung'),
                  ),
                  TextField(
                    controller: plate,
                    decoration: const InputDecoration(labelText: 'Kennzeichen'),
                  ),
                  TextField(
                    controller: height,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Höhe in m'),
                  ),
                  TextField(
                    controller: width,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Breite in m'),
                  ),
                  TextField(
                    controller: length,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Länge in m'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isDefault,
                    title: const Text('Standardfahrzeug'),
                    onChanged: (value) =>
                        setDialogState(() => isDefault = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                final values = [height, width, length]
                    .map(
                      (controller) => double.tryParse(
                        controller.text.replaceAll(',', '.'),
                      ),
                    )
                    .toList();
                if (name.text.trim().isEmpty ||
                    plate.text.trim().isEmpty ||
                    values.any((value) => value == null || value <= 0)) {
                  return;
                }
                try {
                  await ref.read(vehicleRepositoryProvider).save(
                        VehicleRecord(
                          id: vehicle?.id ?? '',
                          name: name.text.trim(),
                          plate: plate.text.trim().toUpperCase(),
                          height: values[0]!,
                          width: values[1]!,
                          length: values[2]!,
                          isDefault: isDefault,
                        ),
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(error.toString())),
                    );
                  }
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );

    for (final controller in [name, plate, height, width, length]) {
      controller.dispose();
    }
    if (saved == true) reload();
  }

  Future<void> _delete(VehicleRecord vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fahrzeug löschen?'),
        content: Text('${vehicle.name} · ${vehicle.plate} wird entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Behalten'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(vehicleRepositoryProvider).delete(vehicle.id);
      reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onEdit,
    required this.onDelete,
  });

  final VehicleRecord vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: T.surface,
              borderRadius: BorderRadius.circular(T.radius),
              border: Border.all(color: T.line),
              boxShadow: T.shadowSmall,
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: T.mintSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.directions_car_filled_outlined,
                    color: T.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        vehicle.plate,
                        style: const TextStyle(
                          color: T.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${vehicle.length.toStringAsFixed(2)} × ${vehicle.width.toStringAsFixed(2)} × ${vehicle.height.toStringAsFixed(2)} m',
                        style: const TextStyle(color: T.muted),
                      ),
                    ],
                  ),
                ),
                if (vehicle.isDefault)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Chip(label: Text('Standard')),
                  ),
                IconButton(
                  tooltip: 'Bearbeiten',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Löschen',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car_outlined, size: 72, color: T.muted),
            const SizedBox(height: 16),
            const Text(
              'Noch kein Fahrzeug',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Fahrzeug hinzufügen'),
            ),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            TextButton(onPressed: onRetry, child: const Text('Erneut versuchen')),
          ],
        ),
      );
}
