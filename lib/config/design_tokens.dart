import 'package:flutter/material.dart';

class T {
  static const porcelain = Color(0xFFF4F3EE);
  static const porcelainDeep = Color(0xFFEAE7DF);
  static const ink = Color(0xFF0B1726);
  static const inkSoft = Color(0xFF172A3F);
  static const mint = Color(0xFF35D7AC);
  static const mintSoft = Color(0xFFDDF8EF);
  static const amber = Color(0xFFFFB44A);
  static const amberSoft = Color(0xFFFFE8C4);
  static const muted = Color(0xFF667487);
  static const subtle = Color(0xFF8B95A3);
  static const surface = Colors.white;
  static const surfaceRaised = Color(0xFFFBFAF7);
  static const surfaceSelected = Color(0xFFEAFBF6);
  static const mapOverlay = Color(0xEFFFFFFB);
  static const success = Color(0xFF168B6A);
  static const warning = Color(0xFFB7791F);
  static const locked = Color(0xFF596579);
  static const line = Color(0xFFE0DED6);
  static const lineStrong = Color(0xFFC7C2B8);

  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
  static const radiusCompact = 14.0;
  static const radius = 24.0;
  static const radiusSpacious = 32.0;
  static const desktop = 900.0;
  static const tablet = 620.0;
  static const desktopPanel = 428.0;
  static const mobileSheetPeek = 248.0;

  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 360);
  static const slow = Duration(milliseconds: 760);
  static const stagger = Duration(milliseconds: 70);
  static const mapTransition = Duration(milliseconds: 980);
  static const emphasized = Curves.easeOutCubic;

  static List<BoxShadow> shadowSmall = [
    BoxShadow(
      color: ink.withOpacity(.08),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];
  static List<BoxShadow> shadow = [
    BoxShadow(
      color: ink.withOpacity(.14),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
  static List<BoxShadow> shadowLarge = [
    BoxShadow(
      color: ink.withOpacity(.18),
      blurRadius: 42,
      offset: const Offset(0, 22),
    ),
  ];
  static List<BoxShadow> markerShadow = [
    BoxShadow(
      color: ink.withOpacity(.22),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}
