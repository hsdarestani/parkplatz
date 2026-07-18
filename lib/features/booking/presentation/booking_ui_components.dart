import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_motion.dart';
import 'booking_screens.dart' as legacy;

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

class PremiumBookingTimeSelector extends StatefulWidget {
  const PremiumBookingTimeSelector({
    super.key,
    required this.onChanged,
  });

  final VoidCallback onChanged;

  @override
  State<PremiumBookingTimeSelector> createState() =>
      _PremiumBookingTimeSelectorState();
}

class _PremiumBookingTimeSelectorState
    extends State<PremiumBookingTimeSelector> {
  static const hours = [8, 10, 12, 14, 16, 18, 20];

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(bookingDateOnly(legacy.selectedStart)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: legacy.selectedStart.hour,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.schedule_outlined),
                    labelText: 'Beginn',
                  ),
                  items: hours
                      .map(
                        (hour) => DropdownMenuItem(
                          value: hour,
                          child: Text('${hour.toString().padLeft(2, '0')}:00'),
                        ),
                      )
                      .toList(),
                  onChanged: (hour) {
                    if (hour == null) return;
                    setState(() {
                      legacy.selectedStart = DateTime(
                        legacy.selectedStart.year,
                        legacy.selectedStart.month,
                        legacy.selectedStart.day,
                        hour,
                      );
                      legacy.selectedEnd = legacy.selectedStart.add(
                        const Duration(hours: 2),
                      );
                    });
                    widget.onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: T.mintSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.timelapse_outlined, color: T.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${bookingDateTime(legacy.selectedStart)} bis ${bookingTime(legacy.selectedEnd)} Uhr',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final initial = legacy.selectedStart.isBefore(today)
        ? today.add(const Duration(days: 1))
        : legacy.selectedStart;
    final date = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
      initialDate: initial,
    );
    if (date == null) return;
    setState(() {
      legacy.selectedStart = DateTime(
        date.year,
        date.month,
        date.day,
        legacy.selectedStart.hour,
      );
      legacy.selectedEnd = legacy.selectedStart.add(
        const Duration(hours: 2),
      );
    });
    widget.onChanged();
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
