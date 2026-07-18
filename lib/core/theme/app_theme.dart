import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';

ThemeData appTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: T.mint,
    brightness: Brightness.light,
    primary: T.ink,
    secondary: T.mint,
    surface: T.surface,
    error: const Color(0xFFC53A3A),
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: T.line),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    fontFamilyFallback: const ['SF Pro Display', 'Segoe UI', 'Roboto', 'Arial'],
    scaffoldBackgroundColor: T.porcelain,
    colorScheme: colorScheme,
    focusColor: T.amber,
    hoverColor: T.mint.withOpacity(.06),
    highlightColor: T.mint.withOpacity(.08),
    splashColor: T.mint.withOpacity(.09),
    visualDensity: VisualDensity.standard,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FreiraumPageTransitionsBuilder(),
        TargetPlatform.iOS: FreiraumPageTransitionsBuilder(),
        TargetPlatform.macOS: FreiraumPageTransitionsBuilder(),
        TargetPlatform.windows: FreiraumPageTransitionsBuilder(),
        TargetPlatform.linux: FreiraumPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FreiraumPageTransitionsBuilder(),
      },
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
        height: 1.02,
      ),
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
        height: 1.05,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: -.8,
        height: 1.08,
      ),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: -.4,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w900),
      titleMedium: TextStyle(fontWeight: FontWeight.w800),
      bodyLarge: TextStyle(height: 1.45),
      bodyMedium: TextStyle(height: 1.4),
    ),
    iconTheme: const IconThemeData(color: T.ink),
    appBarTheme: const AppBarThemeData(
      backgroundColor: T.surface,
      foregroundColor: T.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: T.ink,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
      shape: Border(bottom: BorderSide(color: T.line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return T.ink.withOpacity(.38);
          }
          if (states.contains(WidgetState.hovered)) return T.inkSoft;
          return T.ink;
        }),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        minimumSize: const WidgetStatePropertyAll(Size(44, 52)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 22),
        ),
        elevation: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) ? 4 : 0,
        ),
        shadowColor: WidgetStatePropertyAll(T.ink.withOpacity(.2)),
        overlayColor: WidgetStatePropertyAll(Colors.white.withOpacity(.06)),
        animationDuration: T.fast,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w900, letterSpacing: -.1),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(T.ink),
        minimumSize: const WidgetStatePropertyAll(Size(44, 50)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.hovered) ? T.mint : T.lineStrong,
            width: states.contains(WidgetState.hovered) ? 1.5 : 1,
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? T.mintSoft.withOpacity(.55)
              : Colors.transparent,
        ),
        animationDuration: T.fast,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: T.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: T.surfaceRaised,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: T.mint, width: 2),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
      labelStyle: const TextStyle(color: T.muted, fontWeight: FontWeight.w800),
      floatingLabelStyle: const TextStyle(
        color: T.success,
        fontWeight: FontWeight.w900,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: T.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 18,
      shadowColor: T.ink.withOpacity(.22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.radiusSpacious),
      ),
    ),
    cardTheme: CardThemeData(
      color: T.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.radius),
        side: const BorderSide(color: T.line),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: T.surfaceRaised,
      selectedColor: T.mintSoft,
      side: const BorderSide(color: T.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: T.surface,
      indicatorColor: T.mintSoft,
      elevation: 0,
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
      ),
    ),
    dividerTheme: const DividerThemeData(color: T.line, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: T.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      behavior: SnackBarBehavior.floating,
      elevation: 12,
    ),
    scrollbarTheme: ScrollbarThemeData(
      radius: const Radius.circular(999),
      thickness: const WidgetStatePropertyAll(7),
      thumbColor: WidgetStatePropertyAll(T.ink.withOpacity(.2)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: T.ink,
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      waitDuration: const Duration(milliseconds: 450),
    ),
  );
}

class FreiraumPageTransitionsBuilder extends PageTransitionsBuilder {
  const FreiraumPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .018),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: .992, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
