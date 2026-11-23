import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import 'empty_art.dart';

/// Tajmer za kuvanje: jaje se blago ljulja u vodi koja ključa dok tajmer
/// radi ([running]); prsten oko kruga pokazuje preostalo vreme (kad su
/// poznati [remaining] i [total]), a vreme je ispisano ispod.
class EggTimer extends StatelessWidget {
  const EggTimer({
    super.key,
    this.running = true,
    this.remaining,
    this.total,
    this.size = 180,
  });

  final bool running;
  final Duration? remaining;
  final Duration? total;
  final double size;

  static String format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = EmptyArtColors.of(theme.colorScheme);
    final left = remaining;
    final all = total;
    final progress = left != null && all != null && all > Duration.zero
        ? (left.inMilliseconds / all.inMilliseconds).clamp(0.0, 1.0)
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MotionBuilder(
          duration: const Duration(milliseconds: 3000),
          restValue: 0.35,
          play: running,
          builder: (context, t, _) => MotionCanvas(
            size: size,
            design: 200,
            label: 'Jaje se kuva',
            painter: EmptyArtPainter(
              t,
              colors,
              (canvas, t, c) => eggScene(canvas, t, c, progress),
            ),
          ),
        ),
        if (left != null)
          Text(
            format(left),
            style: theme.textTheme.displaySmall,
            semanticsLabel: 'Preostalo ${format(left)}',
          ),
      ],
    );
  }
}

/// Jaje u loncu sa prstenom preostalog vremena (koordinate 200×200).
void eggScene(Canvas canvas, double t, EmptyArtColors c, double? progress) {
  const center = Offset(100, 104);
  if (progress != null) {
    final ring = Rect.fromCircle(center: center, radius: 90);
    canvas
      ..drawArc(
        ring,
        0,
        2 * math.pi,
        false,
        stroke(c.softLine, width: 5, opacity: 0.4),
      )
      ..drawArc(
        ring,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        stroke(c.primary, width: 5),
      );
  }
  canvas.drawPath(
    Path()
      ..moveTo(60, 112)
      ..lineTo(48, 112)
      ..moveTo(140, 112)
      ..lineTo(152, 112),
    stroke(c.line, width: 4),
  );
  final body = Path()
    ..moveTo(60, 100)
    ..lineTo(60, 140)
    ..quadraticBezierTo(60, 156, 76, 156)
    ..lineTo(124, 156)
    ..quadraticBezierTo(140, 156, 140, 140)
    ..lineTo(140, 100);
  canvas.drawPath(body, fill(c.surface));

  // Jaje se ljulja u vodi.
  final egg = Path()
    ..moveTo(0, -22)
    ..cubicTo(14, -22, 18, 0, 18, 8)
    ..cubicTo(18, 20, 9, 26, 0, 26)
    ..cubicTo(-9, 26, -18, 20, -18, 8)
    ..cubicTo(-18, 0, -14, -22, 0, -22)
    ..close();
  canvas
    ..save()
    ..translate(100, 112 + 3 * math.sin(t * math.pi * 4 + 1))
    ..rotate(deg(6 * math.sin(t * math.pi * 2)))
    ..drawPath(egg, fill(c.tint))
    ..drawPath(egg, stroke(c.line))
    ..restore();

  // Voda preko donje polovine jajeta.
  final w = 3 * math.sin(t * math.pi * 4);
  final y = 118 + w;
  final wave = Path()
    ..moveTo(62, y)
    ..quadraticBezierTo(81, 112 - w, 100, y)
    ..quadraticBezierTo(119, 2 * y - (112 - w), 138, y);
  final water = Path.from(wave)
    ..lineTo(138, 140)
    ..quadraticBezierTo(138, 154, 124, 154)
    ..lineTo(76, 154)
    ..quadraticBezierTo(62, 154, 62, 140)
    ..close();
  canvas
    ..drawPath(water, fill(c.container, opacity: 0.85))
    ..drawPath(wave, stroke(c.softLine, width: 2.5))
    ..drawPath(body, stroke(c.line))
    ..drawLine(const Offset(54, 100), const Offset(146, 100), stroke(c.line));

  const xs = [74.0, 96.0, 122.0];
  for (final (i, x) in xs.indexed) {
    final p = (t * 2 + i / 3) % 1;
    canvas.drawCircle(
      Offset(x, 150 - 30 * p),
      3.5,
      stroke(c.primary, width: 2, opacity: p < 0.9 ? 1 - p : 0),
    );
  }
}
