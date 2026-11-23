import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import 'empty_art.dart';

/// Sve kupljeno: spisak sa tri stavke, kvačice se redom ucrtaju i stavke se
/// precrtaju, pa iskoči znak štikle sa zracima. Igra jednom.
class AllBoughtArt extends StatelessWidget {
  const AllBoughtArt({super.key});

  @override
  Widget build(BuildContext context) => const EmptyArt(
    label: 'Sve je kupljeno',
    duration: Duration(milliseconds: 2200),
    scene: _allBought,
  );
}

void _allBought(Canvas canvas, double t, EmptyArtColors c) {
  final hop = math.sin(math.pi * interval(t, 0.62, 0.78));
  canvas
    ..save()
    ..translate(0, -4 * hop);
  final card = RRect.fromRectAndRadius(
    const Rect.fromLTWH(54, 36, 92, 128),
    const Radius.circular(14),
  );
  canvas
    ..drawRRect(card, fill(c.surface))
    ..drawRRect(card, stroke(c.line));
  const widths = [44.0, 32.0, 38.0];
  for (var i = 0; i < 3; i++) {
    final y = 68.0 + i * 32;
    final check = easeOut(interval(t, 0.08 + i * 0.17, 0.2 + i * 0.17));
    final strike = easeOut(interval(t, 0.14 + i * 0.17, 0.28 + i * 0.17));
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(66, y - 8, 16, 16),
          const Radius.circular(5),
        ),
        stroke(c.line, width: 2.5),
      )
      ..drawPath(
        partial(
          Path()
            ..moveTo(69.5, y)
            ..lineTo(73.5, y + 4)
            ..lineTo(79.5, y - 4),
          check,
        ),
        stroke(c.primary, width: 3.2),
      )
      ..drawLine(
        Offset(92, y),
        Offset(92 + widths[i], y),
        stroke(c.softLine, width: 4),
      )
      ..drawLine(
        Offset(90, y),
        Offset(90 + (4 + widths[i]) * strike, y),
        stroke(c.primary, width: 2.5, opacity: strike == 0 ? 0 : 1),
      );
  }
  canvas.restore();

  // Znak štikle sa zracima.
  const badge = Offset(142, 150);
  final rp = interval(t, 0.66, 0.95);
  if (rp > 0) {
    canvas
      ..save()
      ..translate(badge.dx, badge.dy)
      ..scale(1 + 0.5 * easeOut(rp));
    for (var i = 0; i < 8; i++) {
      final a = deg(i * 45);
      canvas.drawLine(
        Offset(math.cos(a) * 24, math.sin(a) * 24),
        Offset(math.cos(a) * 33, math.sin(a) * 33),
        stroke(c.primary, opacity: 1 - rp),
      );
    }
    canvas.restore();
  }
  final pop = interval(t, 0.62, 0.82);
  if (pop > 0) {
    canvas
      ..save()
      ..translate(badge.dx, badge.dy)
      ..scale(backOut(pop))
      ..drawCircle(Offset.zero, 19, fill(c.primary))
      ..drawPath(
        Path()
          ..moveTo(-8, 0)
          ..lineTo(-2.5, 6)
          ..lineTo(8.5, -6),
        stroke(c.onPrimary, width: 4),
      )
      ..restore();
  }
}
