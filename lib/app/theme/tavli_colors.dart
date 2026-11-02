import 'package:flutter/material.dart';

import '../../domain/theme_choice.dart';

/// Tokeni teme kojih nema u [ColorScheme].
class TavliColors extends ThemeExtension<TavliColors> {
  const TavliColors({
    required this.motif,
    required this.bg,
    required this.line,
    required this.boxLine,
    required this.tints,
  });

  /// Tema čiji motiv crtaju animacije (bosiljak, šafran, borovnice).
  final TavliTheme motif;
  final Color bg;
  final Color line;
  final Color boxLine;
  final List<Color> tints;

  /// Pozadina pločice za i-ti recept (ponavlja se kroz tri boje).
  Color tint(int i) => tints[i % tints.length];

  static TavliColors of(BuildContext context) =>
      Theme.of(context).extension<TavliColors>()!;

  @override
  TavliColors copyWith({
    TavliTheme? motif,
    Color? bg,
    Color? line,
    Color? boxLine,
    List<Color>? tints,
  }) => TavliColors(
    motif: motif ?? this.motif,
    bg: bg ?? this.bg,
    line: line ?? this.line,
    boxLine: boxLine ?? this.boxLine,
    tints: tints ?? this.tints,
  );

  @override
  TavliColors lerp(TavliColors? other, double t) {
    if (other == null) return this;
    return TavliColors(
      motif: t < 0.5 ? motif : other.motif,
      bg: Color.lerp(bg, other.bg, t)!,
      line: Color.lerp(line, other.line, t)!,
      boxLine: Color.lerp(boxLine, other.boxLine, t)!,
      tints: [
        for (var i = 0; i < tints.length; i++)
          Color.lerp(tints[i], other.tints[i % other.tints.length], t)!,
      ],
    );
  }
}
