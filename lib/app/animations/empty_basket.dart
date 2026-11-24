import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import 'empty_art.dart';

/// Prazna nabavka: korpa se zaljulja i smiri, a iz nje izviri prazan
/// spisak sa tri kvadratića koja se pojave jedan po jedan.
class EmptyBasket extends StatelessWidget {
  const EmptyBasket({super.key});

  @override
  Widget build(BuildContext context) => const EmptyArt(
    label: 'Prazna korpa za nabavku',
    duration: Duration(milliseconds: 2100),
    scene: _basket,
  );
}

final Path _body = Path()
  ..moveTo(52, 108)
  ..lineTo(148, 108)
  ..lineTo(136, 160)
  ..quadraticBezierTo(135, 164, 131, 164)
  ..lineTo(69, 164)
  ..quadraticBezierTo(65, 164, 64, 160)
  ..close();

/// Spisak se vidi samo iznad dna korpe: deo u korpi ostaje u korpi.
final Path _aboveBottom = Path()
  ..moveTo(0, 0)
  ..lineTo(200, 0)
  ..lineTo(200, 108)
  ..lineTo(148, 108)
  ..lineTo(136, 160)
  ..lineTo(64, 160)
  ..lineTo(52, 108)
  ..lineTo(0, 108)
  ..close();

void _basket(Canvas canvas, double t, EmptyArtColors c) {
  final a = interval(t, 0, 0.12);
  final sw = interval(t, 0, 0.6);
  final angle = 9 * math.sin(sw * math.pi * 3) * (1 - sw);
  const pivot = Offset(100, 58);
  canvas
    ..save()
    ..translate(pivot.dx, pivot.dy)
    ..rotate(deg(angle))
    ..translate(-pivot.dx, -pivot.dy)
    ..drawPath(
      Path()
        ..moveTo(64, 110)
        ..quadraticBezierTo(64, 58, 100, 58)
        ..quadraticBezierTo(136, 58, 136, 110),
      stroke(c.line, opacity: a),
    );

  // Spisak izviri iz korpe.
  final up = backOut(interval(t, 0.42, 0.74));
  const tilt = Offset(101, 35);
  canvas
    ..save()
    ..clipPath(_aboveBottom)
    ..translate(0, 114 - 72 * up)
    ..translate(tilt.dx, tilt.dy)
    ..rotate(deg(-7 * up))
    ..translate(-tilt.dx, -tilt.dy);
  final paper = RRect.fromRectAndRadius(
    const Rect.fromLTWH(76, 0, 50, 70),
    const Radius.circular(6),
  );
  canvas
    ..drawRRect(paper, fill(c.surface, opacity: a))
    ..drawRRect(paper, stroke(c.line, opacity: a));
  for (var i = 0; i < 3; i++) {
    final p = easeOut(interval(t, 0.68 + i * 0.09, 0.82 + i * 0.09));
    if (p == 0) continue;
    final dx = -6 * (1 - p);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(84 + dx, 11.0 + i * 17, 9, 9),
          const Radius.circular(2.5),
        ),
        stroke(c.primary, width: 2.2, opacity: p),
      )
      ..drawLine(
        Offset(99 + dx, 15.5 + i * 17),
        Offset((i == 2 ? 110 : 117) + dx, 15.5 + i * 17),
        stroke(c.softLine, width: 2.5, opacity: p),
      );
  }
  canvas.restore();

  // Korpa preko spiska, sa pletivom.
  final weave = Path()
    ..moveTo(58, 126)
    ..lineTo(142, 126)
    ..moveTo(62, 144)
    ..lineTo(138, 144)
    ..moveTo(84, 108)
    ..lineTo(88, 164)
    ..moveTo(116, 108)
    ..lineTo(112, 164);
  canvas
    ..drawPath(_body, fill(c.surface, opacity: a))
    ..drawPath(weave, stroke(c.softLine, width: 2.5, opacity: a))
    ..drawPath(_body, stroke(c.line, opacity: a))
    ..restore();
}
