import 'package:flutter/material.dart';

/// iOS-style colours. Orange fills carry dark text; orange text uses a deeper
/// shade so it stays readable on white.
class Palette {
  const Palette._({
    required this.bg,
    required this.desk,
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
    required this.thumb,
  });

  final Color bg;

  /// Surround shown beside the phone-width column on wide windows.
  final Color desk;
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

  /// Selected segment in a segmented control.
  final Color thumb;

  static const light = Palette._(
    bg: Color(0xFFF2F2F7),
    desk: Color(0xFFE2E2E7),
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
    thumb: Colors.white,
  );

  static const dark = Palette._(
    bg: Colors.black,
    desk: Color(0xFF161618),
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
    thumb: Color(0xFF636366),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// The two themes, each built once. Building a theme is surprisingly
/// expensive, so it must not happen on every rebuild.
final ThemeData lightTheme = _buildTheme(Brightness.light);
final ThemeData darkTheme = _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? Palette.dark : Palette.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    // Spelled out from our own palette. `ColorScheme.fromSeed` computes a whole
    // tonal palette at startup and pulls in a large colour-science library we
    // don't otherwise need.
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: p.accentText,
      onPrimary: dark ? Colors.black : Colors.white,
      secondary: p.accent,
      onSecondary: p.onAccent,
      error: const Color(0xFFFF3B30),
      onError: Colors.white,
      surface: p.bg,
      onSurface: p.label,
    ),
    scaffoldBackgroundColor: p.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
