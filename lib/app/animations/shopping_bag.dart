import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'motion.dart';

const _tomato = Color(0xFFE0533D);
const _carrot = Color(0xFFF08A24);
const _leaf = Color(0xFF4E9A62);
const _apple = Color(0xFF8DBF4A);
const _crust = Color(0xFFC98A45);
const _crumb = Color(0xFFE8B873);

/// Sve kupljeno: namirnice upadaju u kesu, a hleb proviri na vrhu.
/// Igra jednom; završna slika je puna kesa.
class ShoppingBagFull extends StatelessWidget {
  const ShoppingBagFull({super.key, this.size = 200});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MotionBuilder(
      repeat: false,
      duration: const Duration(milliseconds: 2400),
      builder: (context, t, _) => MotionCanvas(
        size: size,
        design: 200,
        label: 'Puna kesa za kupovinu',
        painter: BagPainter(
          t,
          bag: colors.primaryContainer,
          bagLine: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// Koordinate 200×200; kesa je od x 50 do 150, otvor na y 84.
class BagPainter extends CustomPainter {
  BagPainter(this.t, {required this.bag, required this.bagLine});

  final double t;
  final Color bag;
  final Color bagLine;

  @override
  void paint(Canvas canvas, Size size) {
    // Hleb raste iz kese (iza prednje strane).
    final bread = Curves.easeOutBack.transform(interval(t, 0.62, 0.9));
    if (bread > 0) {
      canvas.save();
      canvas.translate(112, 96 - 52 * bread);
      canvas.rotate(-0.22);
      final loaf = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, -10, 36, 74),
        const Radius.circular(18),
      );
      canvas.drawRRect(loaf, Paint()..color = _crust);
      final cut = Paint()
        ..color = _crumb
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      for (final y in [4.0, 18.0, 32.0]) {
        canvas.drawLine(Offset(-8, y + 4), Offset(8, y - 2), cut);
      }
      canvas.restore();
    }

    // Namirnice padaju jedna po jedna.
    final items = [
      (80.0, 0.0, _tomato, 13.0),
      (104.0, 0.14, _apple, 12.0),
      (128.0, 0.28, _carrot, 0.0),
      (90.0, 0.42, _tomato, 11.0),
    ];
    for (final (x, start, color, r) in items) {
      final p = Curves.easeIn.transform(interval(t, start, start + 0.2));
      if (p <= 0) continue;
      final y = -20 + 112 * p;
      if (r == 0) {
        // Šargarepa.
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(0.5);
        canvas.drawPath(
          Path()
            ..moveTo(-7, -14)
            ..lineTo(7, -14)
            ..lineTo(0, 18)
            ..close(),
          Paint()..color = color,
        );
        canvas.drawLine(
          const Offset(0, -14),
          const Offset(0, -24),
          Paint()
            ..color = _leaf
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(Offset(x, y), r, Paint()..color = color);
        canvas.drawCircle(Offset(x + 2, y - r + 1), 3, Paint()..color = _leaf);
      }
    }

    // Kesa se malo spusti svaki put kad nešto upadne.
    final squash = [0.2, 0.34, 0.48, 0.62]
        .map((s) => math.sin(math.pi * interval(t, s, s + 0.08)))
        .fold(0.0, math.max);
    canvas.save();
    canvas.translate(100, 170);
    canvas.scale(1 + 0.03 * squash, 1 - 0.04 * squash);
    canvas.translate(-100, -170);
    final body = Path()
      ..moveTo(46, 84)
      ..lineTo(154, 84)
      ..lineTo(146, 164)
      ..quadraticBezierTo(145, 170, 138, 170)
      ..lineTo(62, 170)
      ..quadraticBezierTo(55, 170, 54, 164)
      ..close();
    canvas.drawPath(body, Paint()..color = bag);
    final stroke = Paint()
      ..color = bagLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(body, stroke);
    // Drške.
    canvas.drawArc(
      const Rect.fromLTWH(70, 64, 22, 40),
      math.pi,
      math.pi,
      false,
      stroke,
    );
    canvas.drawArc(
      const Rect.fromLTWH(108, 64, 22, 40),
      math.pi,
      math.pi,
      false,
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BagPainter old) => old.t != t || old.bag != bag;
}
