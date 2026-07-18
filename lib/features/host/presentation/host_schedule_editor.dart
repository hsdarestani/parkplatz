import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/host_availability_models.dart';
import '../data/host_operations_repository.dart';
import 'host_manage_components.dart';

class HostScheduleEditor extends ConsumerStatefulWidget {
  const HostScheduleEditor({
    super.key,
    required this.spaceId,
    required this.basePriceCents,
    required this.initialRules,
  });

  final String spaceId;
  final int basePriceCents;
  final List<HostAvailabilityRule> initialRules;

  @override
  ConsumerState<HostScheduleEditor> createState() => _HostScheduleEditorState();
}

class _HostScheduleEditorState extends ConsumerState<HostScheduleEditor> {
  late List<HostAvailabilityRule> rules = [...widget.initialRules]
    ..sort((a, b) => a.weekday.compareTo(b.weekday));
  late final priceControllers = List.generate(
    7,
    (weekday) {
      final rule = rules.firstWhere((value) => value.weekday == weekday);
      return TextEditingController(
        text: rule.priceOverrideCents == null
            ? ''
            : euros(rule.priceOverrideCents!),
      );
    },
  );
  bool saving = false;

  @override
  void dispose() {
    for (final controller in priceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HostManageCard(
        title: 'Wochenplan und dynamische Preise',
        subtitle:
            'Lege pro Wochentag Öffnungszeiten und einen optionalen Sonderpreis fest.',
        icon: Icons.date_range_outlined,
        trailing: FilledButton.tonalIcon(
          onPressed: saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? 'Speichert …' : 'Wochenplan speichern'),
        ),
        child: Column(children: rules.map(_row).toList()),
      );

  Widget _row(HostAvailabilityRule rule) {
    final index = rules.indexWhere((value) => value.weekday == rule.weekday);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rule.active
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).disabledColor.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: rule.active,
              title: Text(
                _weekdays[rule.weekday],
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              onChanged: (value) => setState(
                () => rules[index] = rule.copyWith(active: value),
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: _timeDropdown(
              label: 'Von',
              value: rule.startTime,
              enabled: rule.active,
              onChanged: (value) => setState(
                () => rules[index] = rule.copyWith(startTime: value),
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: _timeDropdown(
              label: 'Bis',
              value: rule.endTime,
              enabled: rule.active,
              onChanged: (value) => setState(
                () => rules[index] = rule.copyWith(endTime: value),
              ),
            ),
          ),
          SizedBox(
            width: 230,
            child: TextField(
              controller: priceControllers[rule.weekday],
              enabled: rule.active,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Sonderpreis in €',
                hintText: euros(widget.basePriceCents),
                helperText: 'Leer = Basispreis',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeDropdown({
    required String label,
    required String value,
    required bool enabled,
    required ValueChanged<String> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: _times
            .map((time) => DropdownMenuItem(value: time, child: Text(time)))
            .toList(),
        onChanged: enabled
            ? (selected) {
                if (selected != null) onChanged(selected);
              }
            : null,
      );

  Future<void> _save() async {
    final updated = <HostAvailabilityRule>[];
    for (final rule in rules) {
      if (rule.active && rule.endTime.compareTo(rule.startTime) <= 0) {
        _message('${_weekdays[rule.weekday]}: Endzeit muss nach Startzeit liegen.');
        return;
      }
      final value = priceControllers[rule.weekday].text.trim();
      final override = value.isEmpty ? null : parseEuro(value);
      if (value.isNotEmpty && (override == null || override < 50)) {
        _message('${_weekdays[rule.weekday]}: Preis muss mindestens 0,50 € sein.');
        return;
      }
      updated.add(
        rule.copyWith(
          priceOverrideCents: override,
          clearPrice: value.isEmpty,
        ),
      );
    }

    setState(() => saving = true);
    try {
      final saved = await ref
          .read(hostOperationsRepositoryProvider)
          .saveAvailability(widget.spaceId, updated);
      if (mounted) {
        setState(() => rules = saved);
        _message('Wochenplan wurde gespeichert.');
      }
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

const _weekdays = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

const _times = [
  '00:00',
  '06:00',
  '07:00',
  '08:00',
  '09:00',
  '10:00',
  '12:00',
  '14:00',
  '16:00',
  '18:00',
  '20:00',
  '22:00',
  '23:59',
];
