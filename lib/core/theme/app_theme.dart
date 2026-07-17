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
    fontFamily: 'Arial',
    scaffoldBackgroundColor: T.porcelain,
    colorScheme: colorScheme,
    focusColor: T.amber,
    visualDensity: VisualDensity.standard,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: -.8,
      ),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: -.4,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w900),
      titleMedium: TextStyle(fontWeight: FontWeight.w800),
      bodyLarge: TextStyle(height: 1.35),
      bodyMedium: TextStyle(height: 1.35),
    ),
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
      style: FilledButton.styleFrom(
        backgroundColor: T.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: T.ink,
        minimumSize: const Size(44, 48),
        side: const BorderSide(color: T.lineStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: T.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: T.muted, fontWeight: FontWeight.w700),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: T.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.radius),
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
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: T.surface,
      indicatorColor: T.mintSoft,
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    ),
    dividerTheme: const DividerThemeData(color: T.line, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: T.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
