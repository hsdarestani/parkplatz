import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../parking/data/providers.dart';
import '../data/host_operations_repository.dart';
import '../data/host_repository.dart';
import 'host_manage_components.dart';

class HostDetailsEditor extends ConsumerStatefulWidget {
  const HostDetailsEditor({
    super.key,
    required this.space,
    required this.onSaved,
  });

  final HostSpaceRecord space;
  final ValueChanged<HostSpaceRecord> onSaved;

  @override
  ConsumerState<HostDetailsEditor> createState() => _HostDetailsEditorState();
}

class _HostDetailsEditorState extends ConsumerState<HostDetailsEditor> {
  late final title = TextEditingController(text: widget.space.title);
  late final district = TextEditingController(text: widget.space.district);
  late final landmark = TextEditingController(text: widget.space.landmark);
  late final address = TextEditingController(text: widget.space.exactAddress);
  late final instructions =
      TextEditingController(text: widget.space.entranceInstructions);
  late final price =
      TextEditingController(text: euros(widget.space.hourlyPriceCents));
  late final height = TextEditingController(text: decimal(widget.space.maxHeight));
  late final width = TextEditingController(text: decimal(widget.space.maxWidth));
  late final length = TextEditingController(text: decimal(widget.space.maxLength));
  late final latitude =
      TextEditingController(text: widget.space.latitude.toStringAsFixed(6));
  late final longitude =
      TextEditingController(text: widget.space.longitude.toStringAsFixed(6));

  late String accessType = widget.space.accessType;
  late bool covered = widget.space.covered;
  late bool evCharging = widget.space.evCharging;
  late bool accessible = widget.space.accessible;
  late bool instantBookable = widget.space.instantBookable;
  bool saving = false;

  @override
  void dispose() {
    for (final controller in [
      title,
      district,
      landmark,
      address,
      instructions,
      price,
      height,
      width,
      length,
      latitude,
      longitude,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HostManageCard(
        title: 'Angebot bearbeiten',
        subtitle: 'Öffentliche Angaben, Adresse, Maße und Basispreis.',
        icon: Icons.edit_location_alt_outlined,
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field(title, 'Titel', 360),
                _field(district, 'Stadtteil', 250),
                _field(landmark, 'Orientierungspunkt', 330),
                _field(address, 'Genaue Adresse', 500),
                _field(price, 'Basispreis pro Stunde in €', 250, numeric: true),
                _field(height, 'Max. Höhe in m', 210, numeric: true),
                _field(width, 'Max. Breite in m', 210, numeric: true),
                _field(length, 'Max. Länge in m', 210, numeric: true),
                _field(latitude, 'Breitengrad', 220, numeric: true),
                _field(longitude, 'Längengrad', 220, numeric: true),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: instructions,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Zufahrts- und Einparkhinweise',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: accessType,
              decoration: const InputDecoration(labelText: 'Art der Zufahrt'),
              items: const [
                DropdownMenuItem(value: 'open', child: Text('Offene Zufahrt')),
                DropdownMenuItem(value: 'barrier', child: Text('Schranke')),
                DropdownMenuItem(value: 'gate', child: Text('Tor')),
                DropdownMenuItem(
                  value: 'underground',
                  child: Text('Tiefgarage'),
                ),
                DropdownMenuItem(
                  value: 'reception',
                  child: Text('Rezeption / Empfang'),
                ),
              ],
              onChanged: (value) => setState(() => accessType = value ?? 'open'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                HostToggleChip(
                  label: 'Überdacht',
                  icon: Icons.roofing_outlined,
                  selected: covered,
                  onChanged: (value) => setState(() => covered = value),
                ),
                HostToggleChip(
                  label: 'E-Laden',
                  icon: Icons.ev_station_outlined,
                  selected: evCharging,
                  onChanged: (value) => setState(() => evCharging = value),
                ),
                HostToggleChip(
                  label: 'Barrierearm',
                  icon: Icons.accessible_outlined,
                  selected: accessible,
                  onChanged: (value) => setState(() => accessible = value),
                ),
                HostToggleChip(
                  label: 'Sofort buchbar',
                  icon: Icons.bolt_outlined,
                  selected: instantBookable,
                  onChanged: (value) => setState(() => instantBookable = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'Wird gespeichert …' : 'Änderungen speichern'),
              ),
            ),
          ],
        ),
      );

  Widget _field(
    TextEditingController controller,
    String label,
    double fieldWidth, {
    bool numeric = false,
  }) =>
      SizedBox(
        width: fieldWidth,
        child: TextField(
          controller: controller,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
              : TextInputType.text,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Future<void> _save() async {
    final parsedPrice = parseEuro(price.text);
    final parsedHeight = parseDecimal(height.text);
    final parsedWidth = parseDecimal(width.text);
    final parsedLength = parseDecimal(length.text);
    final parsedLatitude = parseDecimal(latitude.text);
    final parsedLongitude = parseDecimal(longitude.text);
    if (title.text.trim().length < 3 ||
        district.text.trim().length < 2 ||
        landmark.text.trim().length < 2 ||
        address.text.trim().length < 5 ||
        instructions.text.trim().length < 5 ||
        parsedPrice == null ||
        parsedPrice < 50 ||
        parsedHeight == null ||
        parsedWidth == null ||
        parsedLength == null ||
        parsedLatitude == null ||
        parsedLongitude == null) {
      _message('Bitte prüfe alle Angaben und Maße.');
      return;
    }

    setState(() => saving = true);
    try {
      final updated = HostSpaceRecord(
        id: widget.space.id,
        title: title.text.trim(),
        district: district.text.trim(),
        landmark: landmark.text.trim(),
        latitude: parsedLatitude,
        longitude: parsedLongitude,
        exactAddress: address.text.trim(),
        entranceInstructions: instructions.text.trim(),
        hourlyPriceCents: parsedPrice,
        maxHeight: parsedHeight,
        maxWidth: parsedWidth,
        maxLength: parsedLength,
        accessType: accessType,
        covered: covered,
        evCharging: evCharging,
        accessible: accessible,
        instantBookable: instantBookable,
        verified: widget.space.verified,
        status: widget.space.status,
      );
      final saved =
          await ref.read(hostOperationsRepositoryProvider).update(updated);
      ref.invalidate(parkingSpacesProvider);
      widget.onSaved(saved);
      if (mounted) _message('Stellplatz wurde aktualisiert.');
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
