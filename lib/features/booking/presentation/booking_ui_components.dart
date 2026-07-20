import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_motion.dart';
import '../../search/presentation/search_controller.dart';

class BookingSurfaceCard extends StatelessWidget {
  const BookingSurfaceCard({
    super.key,
    required this.child,
    this.elevated = false,
  });

  final Widget child;
  final bool elevated;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: T.surface.withOpacity(.97),
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
          boxShadow: elevated ? T.shadow : T.shadowSmall,
        ),
        child: child,
      );
}

class BookingSectionTitle extends StatelessWidget {
  const BookingSectionTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: T.mintSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: T.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(subtitle, style: const TextStyle(color: T.muted)),
              ],
            ),
          ),
        ],
      );
}

class PremiumBookingTimeSelector extends ConsumerWidget {
  const PremiumBookingTimeSelector({
    super.key,
    required this.onChanged,
  });

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickDate(context, ref),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(bookingDateOnly(query.start)),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickStartTime(context, ref),
              icon: const Icon(Icons.login_rounded),
              label: Text('Einfahrt ${bookingTime(query.start)}'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickEndTime(context, ref),
              icon: const Icon(Icons.logout_rounded),
              label: Text('Ausfahrt ${bookingTime(query.end)}'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.timelapse_outlined, color: T.success),
            const SizedBox(width: 9),
            Text(
              '${query.hours} ${query.hours == 1 ? 'Stunde' : 'Stunden'}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        Slider(
          value: query.hours.toDouble(),
          min: 1,
          max: 24,
          divisions: 23,
          label: '${query.hours} Std.',
          onChanged: (value) {
            ref.read(searchProvider.notifier).duration(value.round());
            onChanged();
          },
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: T.mintSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_available_outlined, color: T.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${bookingDateTime(query.start)} bis ${bookingTime(query.end)} Uhr',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final query = ref.read(searchProvider);
    final today = DateTime.now();
    final initial = query.start.isBefore(today) ? today : query.start;
    final date = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDate: initial,
    );
    if (date == null) return;
    ref.read(searchProvider.notifier).start(
          DateTime(
            date.year,
            date.month,
            date.day,
            query.start.hour,
            query.start.minute,
          ),
        );
    onChanged();
  }

  Future<void> _pickStartTime(BuildContext context, WidgetRef ref) async {
    final query = ref.read(searchProvider);
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(query.start),
    );
    if (selected == null) return;
    ref.read(searchProvider.notifier).start(
          DateTime(
            query.start.year,
            query.start.month,
            query.start.day,
            selected.hour,
            selected.minute,
          ),
        );
    onChanged();
  }

  Future<void> _pickEndTime(BuildContext context, WidgetRef ref) async {
    final query = ref.read(searchProvider);
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(query.end),
    );
    if (selected == null) return;
    var end = DateTime(
      query.start.year,
      query.start.month,
      query.start.day,
      selected.hour,
      selected.minute,
    );
    if (!end.isAfter(query.start)) end = end.add(const Duration(days: 1));
    ref.read(searchProvider.notifier).range(query.start, end);
    onChanged();
  }
}

class PremiumRetryState extends StatelessWidget {
  const PremiumRetryState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: MotionReveal(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 56,
                color: T.muted,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
}

String bookingMoney(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

String bookingDateOnly(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
}

String bookingTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String bookingDateTime(DateTime value) =>
    '${bookingDateOnly(value)} · ${bookingTime(value)}';
