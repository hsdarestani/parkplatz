import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/bootstrap.dart';

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE');

  ErrorWidget.builder = (details) => Material(
        color: const Color(0xFFF4F3EE),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFB44A), width: 2),
              ),
              child: SelectableText(
                'FREIRAUM runtime error\n\n${details.exceptionAsString()}',
                style: const TextStyle(
                  color: Color(0xFF0B1726),
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
      );

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('$error\n$stack');
    }
    return false;
  };

  runApp(const ProviderScope(child: FreiraumBootstrap()));
}
