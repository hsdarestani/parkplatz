import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';

class HostManageCard extends StatelessWidget {
  const HostManageCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: T.surface.withOpacity(.97),
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
          boxShadow: T.shadowSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: T.mintSoft,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: T.success),
                ),
                SizedBox(
                  width: 650,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(subtitle, style: const TextStyle(color: T.muted)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      );
}

class HostDarkPill extends StatelessWidget {
  const HostDarkPill({
    super.key,
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: T.mint, size: 16),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class HostToggleChip extends StatelessWidget {
  const HostToggleChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => FilterChip(
        selected: selected,
        onSelected: onChanged,
        avatar: Icon(icon, size: 18),
        label: Text(label),
      );
}

class HostErrorState extends StatelessWidget {
  const HostErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      );
}

int? parseEuro(String value) {
  final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
  return parsed == null ? null : (parsed * 100).round();
}

double? parseDecimal(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

String euros(int cents) =>
    (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

String decimal(double value) =>
    value.toStringAsFixed(2).replaceAll('.', ',');

String hostDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
