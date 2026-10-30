import 'package:flutter/material.dart';

import '../../domain/theme_choice.dart';

/// Boje jedne teme u jednoj osvetljenosti (odobreni dizajn).
class TavliPalette {
  const TavliPalette({
    required this.bg,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.container,
    required this.onContainer,
    required this.text,
    required this.muted,
    required this.line,
    required this.boxLine,
    required this.tints,
  });

  final Color bg;
  final Color surface;
  final Color primary;
  final Color onPrimary;

  /// primaryContainer
  final Color container;

  /// onPrimaryContainer
  final Color onContainer;

  /// onSurface
  final Color text;

  /// onSurfaceVariant
  final Color muted;

  /// outlineVariant: ivice kartica i razdelnici.
  final Color line;

  /// outline: ivice polja za štikliranje.
  final Color boxLine;

  /// Pozadine pločica recepata bez slike.
  final List<Color> tints;

  static TavliPalette of(TavliTheme theme, Brightness brightness) =>
      switch ((theme, brightness)) {
        (TavliTheme.bosiljak, Brightness.light) => bosiljakLight,
        (TavliTheme.bosiljak, Brightness.dark) => bosiljakDark,
        (TavliTheme.safran, Brightness.light) => safranLight,
        (TavliTheme.safran, Brightness.dark) => safranDark,
        (TavliTheme.borovnica, Brightness.light) => borovnicaLight,
        (TavliTheme.borovnica, Brightness.dark) => borovnicaDark,
      };

  static const bosiljakLight = TavliPalette(
    bg: Color(0xFFF8F7F2),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF3D7A57),
    onPrimary: Color(0xFFFFFFFF),
    container: Color(0xFFE2EFE6),
    onContainer: Color(0xFF1F4A33),
    text: Color(0xFF1B1F1C),
    muted: Color(0xFF5C6660),
    line: Color(0xFFE5E3DB),
    boxLine: Color(0xFF8E9892),
    tints: [Color(0xFFF6E7CF), Color(0xFFF3DDD5), Color(0xFFDCE9EE)],
  );

  static const bosiljakDark = TavliPalette(
    bg: Color(0xFF121613),
    surface: Color(0xFF1B201C),
    primary: Color(0xFF7CC79A),
    onPrimary: Color(0xFF0E2A1A),
    container: Color(0xFF24382B),
    onContainer: Color(0xFFBFE6CC),
    text: Color(0xFFE9EDE9),
    muted: Color(0xFFA3AEA7),
    line: Color(0xFF2A312C),
    boxLine: Color(0xFF6F7A73),
    tints: [Color(0xFF3A3222), Color(0xFF3A2A25), Color(0xFF22333A)],
  );

  static const safranLight = TavliPalette(
    bg: Color(0xFFFFF8F2),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFFB24A22),
    onPrimary: Color(0xFFFFFFFF),
    container: Color(0xFFFBE3D6),
    onContainer: Color(0xFF6B2A10),
    text: Color(0xFF2A1E18),
    muted: Color(0xFF6B5A51),
    line: Color(0xFFF0E0D4),
    boxLine: Color(0xFFA08C81),
    tints: [Color(0xFFFFF0C9), Color(0xFFE7EED9), Color(0xFFF6DCE0)],
  );

  static const safranDark = TavliPalette(
    bg: Color(0xFF17120F),
    surface: Color(0xFF211A16),
    primary: Color(0xFFF0956C),
    onPrimary: Color(0xFF3A1405),
    container: Color(0xFF3D2418),
    onContainer: Color(0xFFFFD6C2),
    text: Color(0xFFF3E9E3),
    muted: Color(0xFFB9A79C),
    line: Color(0xFF33271F),
    boxLine: Color(0xFF7E6B60),
    tints: [Color(0xFF3A3220), Color(0xFF2B3324), Color(0xFF3A2529)],
  );

  static const borovnicaLight = TavliPalette(
    bg: Color(0xFFF5F6FA),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF4A55CC),
    onPrimary: Color(0xFFFFFFFF),
    container: Color(0xFFE5E7FA),
    onContainer: Color(0xFF262C7A),
    text: Color(0xFF171A2B),
    muted: Color(0xFF5A5F76),
    line: Color(0xFFE2E4EE),
    boxLine: Color(0xFF8D91A6),
    tints: [Color(0xFFFDE8D8), Color(0xFFDDF0EA), Color(0xFFF3E1F5)],
  );

  static const borovnicaDark = TavliPalette(
    bg: Color(0xFF11131C),
    surface: Color(0xFF1A1D29),
    primary: Color(0xFF9AA3FF),
    onPrimary: Color(0xFF141A5C),
    container: Color(0xFF262B4D),
    onContainer: Color(0xFFD6DAFF),
    text: Color(0xFFE6E8F2),
    muted: Color(0xFFA2A7BD),
    line: Color(0xFF2A2E3E),
    boxLine: Color(0xFF6E7389),
    tints: [Color(0xFF3A2C22), Color(0xFF1F3530), Color(0xFF35253A)],
  );
}
