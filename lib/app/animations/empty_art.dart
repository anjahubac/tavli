import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

/// Boje crteža praznih ekrana, iz izabrane teme.
class EmptyArtColors {
  EmptyArtColors.of(ColorScheme c)
    : container = c.primaryContainer,
      surface = c.surface,
      line = c.outline,
      softLine = c.outlineVariant,
      muted = c.onSurfaceVariant,
      primary = c.primary,
      onPrimary = c.onPrimary;

  /// Krug u pozadini.
  final Color container;

  /// Popuna predmeta (tanjir, stranice, korpa).
  final Color surface;

  /// Linija crteža.
  final Color line;

  /// Tanje, svetlije linije (redovi u svesci, pletivo korpe).
  final Color softLine;
  final Color muted;

  /// Jedan akcenat po crtežu.
  final Color primary;
  final Color onPrimary;

  @override
  bool operator ==(Object other) =>
      other is EmptyArtColors &&
      other.container == container &&
      other.surface == surface &&
      other.line == line &&
      other.primary == primary;

  @override
  int get hashCode => Object.hash(container, surface, line, primary);
}

/// Crta scenu u koordinatama 200×200 za trenutak `t` (0..1).
typedef EmptyScene = void Function(Canvas canvas, double t, EmptyArtColors c);

/// Zajednički okvir svih animacija praznih ekrana: isti krug u pozadini,
/// crtež sveden na istu veličinu ([fit]) i ista širina na svakom tabu.
/// Igra jednom i stane na završnoj slici; uz smanjeno kretanje odmah
/// crta završnu sliku.
class EmptyArt extends StatelessWidget {
  const EmptyArt({
    super.key,
    required this.label,
    required this.duration,
    required this.scene,
    this.fit = 1,
  });

  /// Opis za čitač ekrana.
  final String label;
  final Duration duration;
  final EmptyScene scene;

  /// Koliko se crtež umanji oko centra kruga, da svi budu vizuelno iste
  /// veličine (širok kalendar ili visok frižider se umanje).
  final double fit;

  /// Crtež raste sa prostorom, ali nikad preko ove veličine.
  static const double maxSize = 200;

  /// Deo raspoložive širine koji crtež zauzima.
  static const double widthShare = 0.6;

  static const double _design = 200;
  static const Offset _center = Offset(100, 104);

  @override
  Widget build(BuildContext context) {
    final colors = EmptyArtColors.of(Theme.of(context).colorScheme);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.hasBoundedWidth
            ? math.min(box.maxWidth * widthShare, maxSize)
            : maxSize;
        // Centriran i kad roditelj traži punu širinu.
        return Center(
          widthFactor: 1,
          heightFactor: 1,
          child: MotionBuilder(
            repeat: false,
            duration: duration,
            builder: (context, t, _) => MotionCanvas(
              size: size,
              design: _design,
              label: label,
              painter: _EmptyArtPainter(t, colors, scene, fit),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyArtPainter extends CustomPainter {
  _EmptyArtPainter(this.t, this.colors, this.scene, this.fit);

  final double t;
  final EmptyArtColors colors;
  final EmptyScene scene;
  final double fit;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(EmptyArt._center, 84, Paint()..color = colors.container);
    canvas
      ..save()
      ..translate(EmptyArt._center.dx, EmptyArt._center.dy)
      ..scale(fit)
      ..translate(-EmptyArt._center.dx, -EmptyArt._center.dy);
    scene(canvas, t, colors);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EmptyArtPainter old) =>
      old.t != t ||
      old.colors != colors ||
      old.fit != fit ||
      old.scene != scene;
}

// Pomoćne funkcije za scene.

/// Lako „preskakanje“ na kraju (malo preko cilja pa nazad).
double backOut(double x) {
  const c = 1.6;
  final p = x - 1;
  return 1 + (c + 1) * p * p * p + c * p * p;
}

double easeOut(double x) => Curves.easeOutCubic.transform(x);
double easeIn(double x) => Curves.easeInCubic.transform(x);
double easeInOut(double x) => Curves.easeInOutCubic.transform(x);

/// Stepeni u radijane.
double deg(double d) => d * math.pi / 180;

/// Linija crteža: zaobljeni krajevi i spojevi.
Paint stroke(Color color, {double width = 3, double opacity = 1}) => Paint()
  ..color = color.withValues(alpha: color.a * opacity)
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint fill(Color color, {double opacity = 1}) =>
    Paint()..color = color.withValues(alpha: color.a * opacity);

/// Isprekidana linija po putanji: [dash] crta, [gap] razmak.
Path dashed(Path source, double dash, double gap) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      out.addPath(metric.extractPath(d, d + dash), Offset.zero);
      d += dash + gap;
    }
  }
  return out;
}
