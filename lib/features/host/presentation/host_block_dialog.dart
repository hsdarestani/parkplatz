import 'package:flutter/material.dart';

import 'host_manage_components.dart';

class HostBlockDraft {
  const HostBlockDraft(this.start, this.end, this.reason);

  final DateTime start;
  final DateTime end;
  final String reason;
}

Future<HostBlockDraft?> showHostBlockDialog(BuildContext context) async {
  final now = DateTime.now();
  var start = DateTime(now.year, now.month, now.day + 1, 8);
  var end = start.add(const Duration(hours: 2));
  final reason = TextEditingController();
  String? error;

  final result = await showDialog<HostBlockDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Sperrzeit hinzufügen'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PickerButton(
                label: 'Beginn',
                value: start,
                onTap: () async {
                  final selected = await _pickDateTime(dialogContext, start);
                  if (selected == null) return;
                  setState(() {
                    start = selected;
                    if (!end.isAfter(start)) {
                      end = start.add(const Duration(hours: 2));
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              _PickerButton(
                label: 'Ende',
                value: end,
                onTap: () async {
                  final selected = await _pickDateTime(dialogContext, end);
                  if (selected != null) setState(() => end = selected);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                decoration: const InputDecoration(
                  labelText: 'Grund (optional)',
                  hintText: 'z. B. Eigennutzung oder Wartung',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (!end.isAfter(start)) {
                setState(() => error = 'Das Ende muss nach dem Beginn liegen.');
                return;
              }
              Navigator.pop(
                dialogContext,
                HostBlockDraft(start, end, reason.text.trim()),
              );
            },
            child: const Text('Sperren'),
          ),
        ],
      ),
    ),
  );
  reason.dispose();
  return result;
}

Future<DateTime?> _pickDateTime(
  BuildContext context,
  DateTime current,
) async {
  final date = await showDatePicker(
    context: context,
    initialDate: current,
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 365)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.calendar_month_outlined),
        label: SizedBox(
          width: double.infinity,
          child: Text('$label: ${hostDateTime(value)}'),
        ),
      );
}
