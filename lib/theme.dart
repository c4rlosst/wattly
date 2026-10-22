import 'package:flutter/material.dart';

/// iOS-style colours. Orange fills carry dark text; orange text uses a deeper
/// shade so it stays readable on white.
class Palette {
  const Palette._({
    required this.bg,
    required this.card,
    required this.label,
    required this.secondary,
    required this.separator,
    required this.accent,
    required this.accentText,
    required this.accentSoft,
    required this.onAccent,
    required this.green,
    required this.fill,
  });

  final Color bg;
  final Color card;
  final Color label;
  final Color secondary;
  final Color separator;
  final Color accent;
  final Color accentText;
  final Color accentSoft;
  final Color onAccent;
  final Color green;
  final Color fill;

  static const light = Palette._(
    bg: Color(0xFFF2F2F7),
    card: Colors.white,
    label: Color(0xFF1C1C1E),
    secondary: Color(0xFF6C6C70),
    separator: Color(0x333C3C43),
    accent: Color(0xFFFF9500),
    accentText: Color(0xFFB85400),
    accentSoft: Color(0xFFFFD9A3),
    onAccent: Color(0xFF1C1C1E),
    green: Color(0xFF34C759),
    fill: Color(0x1F767680),
  );

  static const dark = Palette._(
    bg: Colors.black,
    card: Color(0xFF1C1C1E),
    label: Colors.white,
    secondary: Color(0xFF98989F),
    separator: Color(0x54545458),
    accent: Color(0xFFFF9F0A),
    accentText: Color(0xFFFF9F0A),
    accentSoft: Color(0x59FF9F0A),
    onAccent: Color(0xFF1C1C1E),
    green: Color(0xFF30D158),
    fill: Color(0x3D767680),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF9500),
      brightness: brightness,
    ).copyWith(primary: p.accentText, surface: p.bg),
    scaffoldBackgroundColor: p.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
