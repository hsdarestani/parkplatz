import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/brand_config.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class FreiraumApp extends StatefulWidget {
  const FreiraumApp({super.key});

  @override
  State<FreiraumApp> createState() => _FreiraumAppState();
}

class _FreiraumAppState extends State<FreiraumApp> {
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: BrandConfig.name,
        theme: appTheme(),
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
      ),
    );
  }
}
