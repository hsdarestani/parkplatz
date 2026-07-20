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
        _RangeRow(
          icon: Icons.login_rounded,
          title: 'Einfahrt',
          date: bookingDateOnly(query.start),
          time: bookingTime(query.start),
          onDate: () => _pickStartDate(context, ref),
          onTime: () => _pickStartTime(context, ref),
        ),
        const SizedBox(height: 10),
        _RangeRow(
          icon: Icons.logout_rounded,
          title: 'Ausfahrt',
          date: bookingDateOnly(query.end),
          time: bookingTime(query.end),
          onDate: () => _pickEndDate(context, ref),
          onTime: () => _pickEndTime(context, ref),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [T.ink, T.inkSoft]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(Icons.timelapse_rounded, color: T.mint),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gesamtdauer',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      query.durationLabel(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: const [
            (label: '2 Std.', duration: Duration(hours: 2)),
            (label: '4 Std.', duration: Duration(hours: 4)),
            (label: '8 Std.', duration: Duration(hours: 8)),
            (label: '1 Tag', duration: Duration(days: 1)),
            (label: '3 Tage', duration: Duration(days: 3)),
            (label: '7 Tage', duration: Duration(days: 7)),
          ]
              .map(
                (option) => ActionChip(
                  avatar: const Icon(Icons.schedule_rounded, size: 16),
                  label: Text(option.label),
                  onPressed: () {
                    ref
                        .read(searchProvider.notifier)
                        .durationValue(option.duration);
                    onChanged();
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: T.mintSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: T.mint),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_available_rounded, color: T.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${bookingDateTime(query.start)} bis ${bookingDateTime(query.end)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickStartDate(BuildContext context, WidgetRef ref) async {
    final query = ref.read(searchProvider);
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 365)),
      initialDate: query.start.isBefore(today) ? today : query.start,
    );
    if (selected == null) return;
    ref.read(searchProvider.notifier).start(
          DateTime(
            selected.year,
            selected.month,
            selected.day,
            query.start.hour,
            query.start.minute,
          ),
        );
    onChanged();
  }

  Future<void> _pickEndDate(BuildContext context, WidgetRef ref) async {
    final query = ref.read(searchProvider);
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(query.start.year, query.start.month, query.start.day),
      lastDate: query.start.add(const Duration(days: 30)),
      initialDate: query.end.isBefore(query.start) ? query.start : query.end,
    );
    if (selected == null) return;
    var end = DateTime(
      selected.year,
      selected.month,
      selected.day,
      query.end.hour,
      query.end.minute,
    );
    if (!end.isAfter(query.start)) end = query.start.add(const Duration(hours: 1));
    ref.read(searchProvider.notifier).range(query.start, end);
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
      query.end.year,
      query.end.month,
      query.end.day,
      selected.hour,
      selected.minute,
    );
    if (!end.isAfter(query.start)) end = end.add(const Duration(days: 1));
    ref.read(searchProvider.notifier).range(query.start, end);
    onChanged();
  }
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({
    required this.icon,
    required this.title,
    required this.date,
    required this.time,
    required this.onDate,
    required this.onTime,
  });

  final IconData icon;
  final String title;
  final String date;
  final String time;
  final VoidCallback onDate;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: T.surfaceRaised,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: T.line),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: T.mintSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: T.success),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text('$date · $time', style: const TextStyle(color: T.muted)),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Datum ändern',
              onPressed: onDate,
              icon: const Icon(Icons.calendar_today_outlined),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              tooltip: 'Uhrzeit ändern',
              onPressed: onTime,
              icon: const Icon(Icons.schedule_rounded),
            ),
          ],
        ),
      );
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
