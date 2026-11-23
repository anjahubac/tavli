import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import 'empty_art.dart';

const _light = Color(0xFFFFF1B8);

/// Prazna ostava: vrata frižidera se otvore, svetlo se postepeno upali,
/// unutra nema ničega osim jedne pahulje koja se spusti na donju policu.
/// Igra jednom; završna slika su otvorena vrata, svetlo i pahulja.
class EmptyFridge extends StatelessWidget {
  const EmptyFridge({super.key});

  @override
  Widget build(BuildContext context) => const EmptyArt(
    label: 'Prazan frižider',
    duration: Duration(milliseconds: 2600),
    fit: 0.8,
    scene: _fridge,
  );
}

/// Svetlo se mirno upali dok se vrata otvaraju.
double fridgeLight(double t) =>
    Curves.easeOut.transform(interval(t, 0.2, 0.65));

void _fridge(Canvas canvas, double t, EmptyArtColors c) {
  FridgePainter(
    t,
    body: c.surface,
    line: c.line,
    inside: c.surface,
    door: Color.lerp(c.surface, c.primary, 0.3)!,
  ).paint(canvas, Size.zero);

  // Pahulja izleti iz frižidera i spusti se na donju policu.
  final f = interval(t, 0.62, 1);
  if (f == 0) return;
  final flake = Path()
    ..moveTo(0, -8)
    ..lineTo(0, 8)
    ..moveTo(-7, -4)
    ..lineTo(7, 4)
    ..moveTo(-7, 4)
    ..lineTo(7, -4);
  canvas
    ..save()
    ..translate(112 + 5 * math.sin(f * math.pi * 2), 82 + 58 * easeOut(f) - 9)
    ..rotate(deg(120 * f))
    ..drawPath(
      flake,
      stroke(c.primary, width: 2.4, opacity: math.min(1, f * 4)),
    )
    ..restore();
}

/// Koordinate 200×200; frižider od x 56 do 144.
class FridgePainter extends CustomPainter {
  FridgePainter(
    this.t, {
    required this.body,
    required this.line,
    required this.inside,
    required this.door,
  });

  final double t;
  final Color body;
  final Color line;
  final Color inside;
  final Color door;

  @override
  void paint(Canvas canvas, Size size) {
    const box = Rect.fromLTRB(56, 20, 144, 184);
    final rbox = RRect.fromRectAndRadius(box, const Radius.circular(12));
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final light = fridgeLight(t);

    // Unutrašnjost: police i svetlo.
    canvas.drawRRect(rbox, Paint()..color = inside);
    canvas.drawRRect(
      rbox,
      Paint()..color = _light.withValues(alpha: 0.9 * light),
    );
    canvas.drawCircle(
      const Offset(100, 34),
      5,
      Paint()..color = Color.lerp(line, _light, light)!,
    );
    for (final y in [70.0, 112.0, 150.0]) {
      canvas.drawLine(Offset(62, y), Offset(138, y), stroke);
    }
    canvas.drawRRect(rbox, stroke);

    // Vrata (šarka levo) se skupljaju ka šarki dok se otvaraju.
    final open = Curves.easeInOutCubic.transform(interval(t, 0, 0.36));
    final width = (box.width) * (1 - open) + 14 * open;
    final left = box.left - 14 * open;
    final doorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, box.top, width, box.height),
      const Radius.circular(12),
    );
    canvas.drawRRect(doorRect, Paint()..color = Color.lerp(door, body, open)!);
    canvas.drawRRect(doorRect, stroke);
    if (open < 0.6) {
      // Ručka.
      canvas.drawLine(
        Offset(left + width - 14, 60),
        Offset(left + width - 14, 92),
        stroke..strokeWidth = 5,
      );
    }
  }

  @override
  bool shouldRepaint(FridgePainter old) => old.t != t || old.body != body;
}
