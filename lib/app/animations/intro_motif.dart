import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/theme_choice.dart';
import '../theme/tavli_colors.dart';
import 'motion.dart';

/// Motiv teme u krugu: grančica bosiljka sa listovima koji padaju, cvet
/// šafrana koji se otvara ili borovnice koje upadaju u činiju.
class IntroMotif extends StatelessWidget {
  const IntroMotif({super.key, this.motif, this.size = 280});

  /// null: motiv aktivne teme.
  final TavliTheme? motif;
  final double size;

  static String labelFor(TavliTheme motif) => switch (motif) {
    TavliTheme.bosiljak => 'Grančica bosiljka',
    TavliTheme.safran => 'Cvet šafrana',
    TavliTheme.borovnica => 'Borovnice padaju u činiju',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final m = motif ?? TavliColors.of(context).motif;
    final (duration, rest) = switch (m) {
      TavliTheme.bosiljak => (const Duration(seconds: 7), 0.3),
      TavliTheme.safran => (const Duration(seconds: 5), 0.6),
      TavliTheme.borovnica => (const Duration(seconds: 4), 0.7),
    };
    return ClipOval(
      child: ColoredBox(
        color: colors.primaryContainer,
        child: MotionBuilder(
          duration: duration,
          restValue: rest,
          builder: (context, t, still) => MotionCanvas(
            size: size,
            label: labelFor(m),
            painter: switch (m) {
              TavliTheme.bosiljak => BasilPainter(t, still: still),
              TavliTheme.safran => SaffronPainter(t, still: still),
              TavliTheme.borovnica => BlueberryPainter(
                t,
                still: still,
                bowl: colors.surface,
                bowlLine: colors.outlineVariant,
              ),
            },
          ),
        ),
      ),
    );
  }
}

const _basilDark = Color(0xFF2F6B43);
const _basilLeaves = [Color(0xFF4E9A62), Color(0xFF5BAA6E), Color(0xFF6DBB7E)];

Path _leaf(double half) => Path()
  ..moveTo(0, -half)
  ..cubicTo(half * 0.62, -half * 0.56, half * 0.62, half * 0.44, 0, half)
  ..cubicTo(-half * 0.62, half * 0.44, -half * 0.62, -half * 0.56, 0, -half)
  ..close();

/// Bosiljak: grančica se njiše, listovi padaju (koordinate 280×280).
class BasilPainter extends CustomPainter {
  BasilPainter(this.t, {this.still = false});

  final double t;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = _basilDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(140, 250);
    canvas.rotate(math.sin(t * 4 * math.pi) * 0.07);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..cubicTo(0, -40, -2, -90, 0, -150),
      stem,
    );
    void leaf(List<double> c, Color color) {
      canvas.drawPath(
        Path()
          ..moveTo(0, c[0])
          ..cubicTo(c[1], c[2], c[3], c[4], c[5], c[6])
          ..cubicTo(c[7], c[8], c[9], c[10], 0, c[0])
          ..close(),
        Paint()..color = color,
      );
    }

    leaf([
      -60,
      -20,
      -70,
      -52,
      -66,
      -64,
      -40,
      -40,
      -34,
      -14,
      -40,
    ], _basilLeaves[0]);
    leaf([-80, 20, -92, 54, -88, 66, -60, 40, -54, 14, -60], _basilLeaves[1]);
    leaf([
      -112,
      -18,
      -124,
      -46,
      -120,
      -56,
      -98,
      -34,
      -92,
      -12,
      -96,
    ], _basilLeaves[1]);
    leaf([
      -150,
      -16,
      -150,
      -22,
      -132,
      -12,
      -122,
      -4,
      -128,
      2,
      -140,
    ], _basilLeaves[2]);
    leaf([
      -150,
      16,
      -150,
      22,
      -132,
      12,
      -122,
      4,
      -128,
      -2,
      -140,
    ], _basilLeaves[2]);
    canvas.restore();

    // Listovi koji padaju: x, faza, polovina dužine.
    const falling = [
      (46.0, 0.0, 16.0),
      (96.0, 0.3, 12.0),
      (166.0, 0.82, 10.0),
      (200.0, 0.62, 16.0),
      (240.0, 0.15, 12.0),
    ];
    for (final (i, (x, phase, half)) in falling.indexed) {
      final p = (t + phase) % 1;
      final y = -40 + 300 * p;
      final fade = still
          ? 1.0
          : math.min(1.0, math.min(p / 0.1, (1 - p) / 0.1));
      canvas.save();
      canvas.translate(x + math.sin(p * 2 * math.pi) * 14, y);
      canvas.rotate(math.sin(p * 3 * math.pi) * 0.45);
      canvas.drawPath(
        _leaf(half),
        Paint()..color = _basilLeaves[i % 3].withValues(alpha: fade),
      );
      canvas.drawLine(
        Offset(0, -half * 0.85),
        Offset(0, half * 0.85),
        Paint()
          ..color = _basilDark.withValues(alpha: fade)
          ..strokeWidth = 1.4,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(BasilPainter old) => old.t != t || old.still != still;
}

const _petals = [Color(0xFFA688DB), Color(0xFF8E6FCB)];
const _stigma = Color(0xFFD9481C);
const _stem = Color(0xFF6E9A5A);

/// Šafran: cvet se otvara, crvene niti rastu i lebde (koordinate 280×280).
class SaffronPainter extends CustomPainter {
  SaffronPainter(this.t, {this.still = false});

  final double t;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = _stem
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(140, 150)
        ..cubicTo(138, 190, 142, 220, 140, 260),
      stem..strokeWidth = 5,
    );
    canvas.drawPath(
      Path()
        ..moveTo(140, 230)
        ..cubicTo(120, 210, 110, 190, 112, 170),
      stem..strokeWidth = 4,
    );

    for (var i = 0; i < 6; i++) {
      final local = (t - i * 0.02).clamp(0.0, 1.0);
      final open = local < 0.35
          ? Curves.easeInOut.transform(local / 0.35)
          : local < 0.8
          ? 1.0
          : 1 - Curves.easeInOut.transform((local - 0.8) / 0.2);
      final s = 0.15 + 0.85 * open;
      canvas.save();
      canvas.translate(140, 150);
      canvas.rotate(i * math.pi / 3);
      canvas.scale(s);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -40), width: 36, height: 80),
        Paint()..color = _petals[i % 2],
      );
      canvas.restore();
    }
    canvas.drawCircle(
      const Offset(140, 150),
      10,
      Paint()..color = const Color(0xFFF4C542),
    );

    final thread = Paint()
      ..color = _stigma
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final grow =
        Curves.easeOut.transform(interval(t, 0.25, 0.5)) *
        (1 - interval(t, 0.78, 0.95));
    for (final (angle, length) in [(-0.38, 50.0), (0.0, 56.0), (0.38, 50.0)]) {
      canvas.save();
      canvas.translate(140, 150);
      canvas.rotate(angle);
      canvas.drawLine(Offset.zero, Offset(0, -length * grow), thread);
      canvas.restore();
    }

    // Niti koje lebde naviše.
    for (final (x, y, phase, len) in const [
      (70.0, 200.0, 0.0, 14.0),
      (214.0, 190.0, 0.4, 12.0),
      (196.0, 236.0, 0.7, 10.0),
    ]) {
      final p = (t + phase) % 1;
      final alpha = still
          ? 1.0
          : math.min(1.0, math.min(p / 0.2, (1 - p) / 0.2));
      canvas.save();
      canvas.translate(x, y + 20 - 100 * p);
      canvas.rotate(p * math.pi / 2);
      canvas.drawLine(
        Offset.zero,
        Offset(0, len),
        Paint()
          ..color = _stigma.withValues(alpha: alpha)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(SaffronPainter old) => old.t != t || old.still != still;
}

const _berries = [Color(0xFF3E4AA8), Color(0xFF4A55CC), Color(0xFF5A64D6)];
const _crown = Color(0xFF262C7A);

/// Visina skoka borovnice u trenutku `p` (0 = u činiji, negativno = gore).
double _berryY(double p) {
  if (p < 0.3) return -190 * (1 - Curves.easeIn.transform(p / 0.3));
  if (p < 0.38) return -22 * Curves.easeOut.transform(interval(p, 0.3, 0.38));
  if (p < 0.46) {
    return -22 * (1 - Curves.easeIn.transform(interval(p, 0.38, 0.46)));
  }
  if (p < 0.51) return -6 * interval(p, 0.46, 0.51);
  if (p < 0.56) return -6 * (1 - interval(p, 0.51, 0.56));
  return 0;
}

/// Borovnica: bobice padaju i odskaču u činiji (koordinate 280×280).
class BlueberryPainter extends CustomPainter {
  BlueberryPainter(
    this.t, {
    this.still = false,
    required this.bowl,
    required this.bowlLine,
  });

  final double t;
  final bool still;
  final Color bowl;
  final Color bowlLine;

  @override
  void paint(Canvas canvas, Size size) {
    const berries = [
      (100.0, 186.0, 16.0, 0.0),
      (140.0, 180.0, 18.0, 0.2),
      (178.0, 186.0, 16.0, 0.4),
      (120.0, 170.0, 14.0, 0.6),
      (160.0, 168.0, 14.0, 0.8),
    ];
    for (final (i, (x, y, r, phase)) in berries.indexed) {
      final p = still ? 0.7 : (t + phase) % 1;
      final alpha = still
          ? 1.0
          : p < 0.08
          ? p / 0.08
          : p > 0.85
          ? (1 - p) / 0.15
          : 1.0;
      final c = Offset(x, y + _berryY(p));
      canvas.drawCircle(
        c,
        r,
        Paint()..color = _berries[i % 3].withValues(alpha: alpha),
      );
      canvas.drawCircle(
        c + Offset(-r * 0.32, -r * 0.38),
        r * 0.25,
        Paint()..color = Colors.white.withValues(alpha: 0.35 * alpha),
      );
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r - 1)
          ..relativeLineTo(3, -5)
          ..relativeLineTo(2, 4)
          ..relativeLineTo(-5, 3)
          ..relativeLineTo(-5, -3)
          ..relativeLineTo(2, -4)
          ..close(),
        Paint()..color = _crown.withValues(alpha: alpha),
      );
    }
    final bowlPath = Path()
      ..moveTo(50, 190)
      ..lineTo(230, 190)
      ..arcToPoint(
        const Offset(50, 190),
        radius: const Radius.elliptical(90, 58),
      )
      ..close();
    canvas.drawPath(bowlPath, Paint()..color = bowl);
    canvas.drawPath(
      bowlPath,
      Paint()
        ..color = bowlLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(BlueberryPainter old) =>
      old.t != t || old.still != still || old.bowl != bowl;
}
