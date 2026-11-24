import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Uvećanje teksta u kome veliki naslovi rastu sporije od običnog teksta,
/// kao nelinearno uvećanje na iOS-u i Androidu 14.
///
/// Tekst do [bodySize] dobija puno sistemsko uvećanje (do 2× i više). Od
/// [headingSize] naviše uvećanje je najviše [headingMaxFactor]; između se
/// prelazi postepeno, a naslov nikad ne ispadne sitniji od običnog teksta.
@immutable
class TavliTextScaler extends TextScaler {
  const TavliTextScaler(this.system);

  /// Uvećanje koje je korisnik izabrao u sistemu.
  final TextScaler system;

  static const double bodySize = 16;
  static const double headingSize = 28;
  static const double headingMaxFactor = 1.5;

  @override
  double scale(double fontSize) {
    final full = system.scale(fontSize);
    if (fontSize <= bodySize || full <= fontSize * headingMaxFactor) {
      return full;
    }
    // Naslov nikad nije sitniji od običnog teksta (bitno iznad 2,6×).
    final body = system.scale(bodySize);
    final heading = math.max(headingSize * headingMaxFactor, body);
    if (fontSize >= headingSize) {
      return math.max(fontSize * headingMaxFactor, body);
    }
    // Između linearno, da veći font nikad ne ispadne manji.
    final t = (fontSize - bodySize) / (headingSize - bodySize);
    return math.min(full, body + (heading - body) * t);
  }

  @override
  // Zastareli API traži broj; daje uvećanje običnog teksta.
  // ignore: deprecated_member_use
  double get textScaleFactor => system.textScaleFactor;

  @override
  bool operator ==(Object other) =>
      other is TavliTextScaler && other.system == system;

  @override
  int get hashCode => Object.hash(TavliTextScaler, system);
}

/// Primenjuje [TavliTextScaler] na sve ispod sebe (u `MaterialApp.builder`).
class TavliTextScaling extends StatelessWidget {
  const TavliTextScaling({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.textScalerOf(context);
    final scaler = system is TavliTextScaler ? system : TavliTextScaler(system);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: child,
    );
  }
}

/// Da li je tekst uvećan toliko (više od 1,25×) da raspored u više kolona
/// treba zameniti jednom kolonom.
bool isLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(TavliTextScaler.bodySize) >
    TavliTextScaler.bodySize * largeTextFactor;

/// Prag uvećanja za [isLargeText].
const double largeTextFactor = 1.25;
