import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_motion.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../data/payment_repository.dart';

class PaymentReturnScreen extends ConsumerStatefulWidget {
  const PaymentReturnScreen({
    super.key,
    required this.sessionId,
    this.bookingId,
  });

  final String sessionId;
  final String? bookingId;

  @override
  ConsumerState<PaymentReturnScreen> createState() => _PaymentReturnScreenState();
}

class _PaymentReturnScreenState extends ConsumerState<PaymentReturnScreen> {
  String status = 'pending';
  String? error;
  int attempts = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    timer?.cancel();
    try {
      final result = await ref
          .read(paymentRepositoryProvider)
          .checkoutStatus(widget.sessionId);
      if (!mounted) return;
      setState(() {
        status = result.status;
        error = null;
        attempts += 1;
      });
      if (result.status == 'paid') {
        context.go('/booking/${result.bookingId}/confirmed');
        return;
      }
      if ({'failed', 'expired', 'refunded'}.contains(result.status)) return;
      if (attempts < 20) {
        timer = Timer(const Duration(seconds: 2), _check);
      }
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString();
        attempts += 1;
      });
      if (attempts < 20) {
        timer = Timer(const Duration(seconds: 2), _check);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Zahlung wird bestätigt',
        subtitle: 'Wir gleichen deine Zahlung sicher mit der Buchung ab.',
        activePath: '/bookings',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: MotionReveal(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: T.surface,
                    borderRadius: BorderRadius.circular(T.radiusSpacious),
                    border: Border.all(color: T.line),
                    boxShadow: T.shadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status == 'failed' || status == 'expired')
                        const Icon(
                          Icons.error_outline,
                          size: 72,
                          color: T.warning,
                        )
                      else
                        const SizedBox(
                          width: 68,
                          height: 68,
                          child: CircularProgressIndicator(strokeWidth: 6),
                        ),
                      const SizedBox(height: 22),
                      Text(
                        _title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: T.muted),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      if (status == 'failed' || status == 'expired')
                        FilledButton.icon(
                          onPressed: () => context.go('/bookings'),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Buchungen ansehen'),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _check,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Status erneut prüfen'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  String get _title => switch (status) {
        'failed' => 'Zahlung fehlgeschlagen',
        'expired' => 'Zahlungszeit abgelaufen',
        'refunded' => 'Zahlung wurde erstattet',
        _ => 'Zahlung wird verarbeitet',
      };

  String get _message => switch (status) {
        'failed' => 'Die Reservierung wurde nicht bestätigt. Es wurde kein Parking Pass erstellt.',
        'expired' => 'Der reservierte Zeitraum wurde wieder freigegeben.',
        'refunded' => 'Der Betrag wurde zur Erstattung vorgemerkt.',
        _ => 'Das dauert normalerweise nur wenige Sekunden. Bitte schließe diese Seite nicht.',
      };
}
