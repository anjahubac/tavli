import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

const _shell = Color(0xFFF6E6CF);
const _shellLine = Color(0xFFD9BE98);

/// Tajmer za kuvanje: jaje se blago ljulja u vodi koja ključa dok tajmer
/// radi ([running]); preostalo vreme ispod.
class EggTimer extends StatelessWidget {
  const EggTimer({
    super.key,
    this.running = true,
    this.remaining,
    this.size = 180,
  });

  final bool running;
  final Duration? remaining;
  final double size;

  static String format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final left = remaining;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MotionBuilder(
          duration: const Duration(milliseconds: 1600),
          restValue: 0.25,
          play: running,
          builder: (context, t, _) => MotionCanvas(
            size: size,
            design: 200,
            label: 'Jaje se kuva',
            painter: EggPainter(
              t,
              pot: colors.primary,
              water: colors.primaryContainer,
              bubble: colors.onPrimaryContainer,
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

/// Koordinate 200×200.
class EggPainter extends CustomPainter {
  EggPainter(
    this.t, {
    required this.pot,
    required this.water,
    required this.bubble,
  });

  final double t;
  final Color pot;
  final Color water;
  final Color bubble;

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    final body = RRect.fromLTRBAndCorners(
      36,
      70,
      164,
      170,
      bottomLeft: const Radius.circular(26),
      bottomRight: const Radius.circular(26),
    );
    canvas.drawRRect(body, Paint()..color = pot);
    final waterRect = RRect.fromLTRBAndCorners(
      44,
      92,
      156,
      162,
      bottomLeft: const Radius.circular(20),
      bottomRight: const Radius.circular(20),
    );
    canvas.drawRRect(waterRect, Paint()..color = water);

    // Jaje: blago gore-dole i naginje se.
    canvas.save();
    canvas.translate(100, 104 + 6 * math.sin(a));
    canvas.rotate(0.18 * math.sin(a + 0.6));
    final egg = Rect.fromCenter(center: Offset.zero, width: 40, height: 52);
    canvas.drawOval(egg, Paint()..color = _shell);
    canvas.drawOval(
      egg,
      Paint()
        ..color = _shellLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();

    // Voda preko donje polovine jajeta.
    canvas.save();
    canvas.clipRRect(waterRect);
    final surface = Path()..moveTo(40, 112);
    for (var x = 40.0; x <= 160; x += 10) {
      surface.lineTo(x, 110 + 3 * math.sin(a * 2 + x / 12));
    }
    surface
      ..lineTo(160, 170)
      ..lineTo(40, 170)
      ..close();
    canvas.drawPath(surface, Paint()..color = water.withValues(alpha: 0.85));
    // Mehurići.
    for (final (x, phase) in const [
      (62.0, 0.0),
      (84.0, 0.5),
      (122.0, 0.25),
      (140.0, 0.75),
    ]) {
      final p = (t * 2 + phase) % 1;
      canvas.drawCircle(
        Offset(x + 3 * math.sin(p * 6), 156 - 46 * p),
        2.5 + 3 * p,
        Paint()
          ..color = bubble.withValues(alpha: 0.5 * (1 - p))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.restore();

    canvas.drawRRect(
      RRect.fromLTRBR(28, 64, 172, 74, const Radius.circular(5)),
      Paint()..color = pot,
    );
  }

  @override
  bool shouldRepaint(EggPainter old) => old.t != t || old.pot != pot;
}
