import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import 'empty_art.dart';

/// Početna bez obroka: sto se postavlja. Tanjir doskoči na sredinu,
/// viljuška i nož kliznu sa strane, na tanjiru blesne odsjaj.
class EmptyTable extends StatelessWidget {
  const EmptyTable({super.key});

  @override
  Widget build(BuildContext context) => const EmptyArt(
    label: 'Postavljen sto',
    duration: Duration(milliseconds: 1700),
    fit: 0.95,
    scene: _table,
  );
}

void _table(Canvas canvas, double t, EmptyArtColors c) {
  // Tanjir.
  final s = 0.4 + 0.6 * backOut(interval(t, 0, 0.42));
  final o = interval(t, 0, 0.12);
  const plate = Offset(100, 108);
  canvas
    ..save()
    ..translate(plate.dx, plate.dy)
    ..scale(s)
    ..translate(-plate.dx, -plate.dy)
    ..drawCircle(plate, 46, fill(c.surface, opacity: o))
    ..drawCircle(plate, 46, stroke(c.line, opacity: o))
    ..drawCircle(plate, 31, stroke(c.softLine, width: 2.5, opacity: o))
    ..restore();

  // Viljuška sleva, nož zdesna.
  final f = easeOut(interval(t, 0.3, 0.62));
  final fork = Path()
    ..moveTo(34, 70)
    ..lineTo(34, 84)
    ..moveTo(41, 70)
    ..lineTo(41, 84)
    ..moveTo(48, 70)
    ..lineTo(48, 84)
    ..moveTo(34, 84)
    ..quadraticBezierTo(41, 92, 48, 84)
    ..moveTo(41, 89)
    ..lineTo(41, 146);
  canvas
    ..save()
    ..translate(-28 * (1 - f), 0)
    ..drawPath(fork, stroke(c.line, opacity: f))
    ..restore();

  final k = easeOut(interval(t, 0.4, 0.72));
  final knife = Path()
    ..moveTo(160, 146)
    ..lineTo(160, 70)
    ..quadraticBezierTo(170, 80, 168, 108)
    ..lineTo(160, 108);
  canvas
    ..save()
    ..translate(28 * (1 - k), 0)
    ..drawPath(knife, fill(c.surface, opacity: k))
    ..drawPath(knife, stroke(c.line, opacity: k))
    ..restore();

  // Odsjaj: zvezdica iskoči pa se malo smiri, uz tačkicu pored.
  final sh = interval(t, 0.72, 1);
  if (sh > 0) {
    final pop = sh < 0.5 ? backOut(sh * 2) : 1 - 0.35 * easeOut((sh - 0.5) * 2);
    final star = Path()
      ..moveTo(0, -9)
      ..quadraticBezierTo(1.5, -1.5, 9, 0)
      ..quadraticBezierTo(1.5, 1.5, 0, 9)
      ..quadraticBezierTo(-1.5, 1.5, -9, 0)
      ..quadraticBezierTo(-1.5, -1.5, 0, -9)
      ..close();
    canvas
      ..save()
      ..translate(128, 84)
      ..scale(pop)
      ..rotate(deg(45 * sh))
      ..drawPath(star, fill(c.primary))
      ..restore();
  }
  final dot = easeOut(interval(t, 0.8, 1));
  if (dot > 0) {
    canvas.drawCircle(const Offset(140, 98), 3 * dot, fill(c.primary));
  }
}

/// Plan bez obroka: nedelja sa praznim danima, a tanjir u luku sleti u
/// sredu i taj dan se popuni.
class EmptyWeek extends StatelessWidget {
  const EmptyWeek({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return EmptyArt(
      label: 'Obrok u nedelji',
      duration: const Duration(milliseconds: 1900),
      fit: 0.84,
      scene: (canvas, t, c) => _week(canvas, t, c, style),
    );
  }
}

const _days = ['P', 'U', 'S', 'Č', 'P', 'S', 'N'];
const _today = 2;

void _week(Canvas canvas, double t, EmptyArtColors c, TextStyle? style) {
  final a = easeOut(interval(t, 0, 0.22));
  canvas
    ..save()
    ..translate(0, 10 * (1 - a));
  final card = RRect.fromRectAndRadius(
    const Rect.fromLTWH(22, 54, 156, 106),
    const Radius.circular(16),
  );
  canvas
    ..drawRRect(card, fill(c.surface, opacity: a))
    ..drawRRect(card, stroke(c.line, opacity: a))
    ..drawPath(
      Path()
        ..moveTo(56, 48)
        ..lineTo(56, 60)
        ..moveTo(144, 48)
        ..lineTo(144, 60),
      stroke(c.line, opacity: a),
    );

  final filled = easeOut(interval(t, 0.62, 0.9));
  for (var i = 0; i < _days.length; i++) {
    final x = 37.0 + i * 21;
    final today = i == _today;
    final letter = TextPainter(
      text: TextSpan(
        text: _days[i],
        style: (style ?? const TextStyle()).copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: (today ? c.primary : c.muted).withValues(alpha: a),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    letter.paint(canvas, Offset(x - letter.width / 2, 68));

    final slot = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - 8, 86, 16, 60),
      const Radius.circular(8),
    );
    final on = today && filled > 0;
    if (on) {
      canvas.drawRRect(slot, fill(c.primary, opacity: 0.16 * filled * a));
    }
    final outline = Path()..addRRect(slot);
    canvas.drawPath(
      on && filled > 0.4 ? outline : dashed(outline, 3, 4),
      stroke(
        on ? c.primary : c.line,
        width: 2,
        opacity: (0.7 + (on ? 0.3 * filled : 0)) * a,
      ),
    );
  }
  canvas.restore();

  // Tanjir u luku sleti u sredu, malo se spljošti pri doskoku.
  final fl = easeIn(interval(t, 0.22, 0.62));
  final x = 150 + (79 - 150) * fl;
  final y = 18 + (116 - 18) * fl - 30 * math.sin(math.pi * fl);
  final sq = math.sin(math.pi * interval(t, 0.62, 0.82));
  final o = interval(t, 0.22, 0.3);
  if (o == 0) return;
  canvas
    ..save()
    ..translate(x, y)
    ..scale(1 + 0.18 * sq, 1 - 0.18 * sq)
    ..rotate(deg(-40 * (1 - fl)))
    ..drawCircle(Offset.zero, 9.5, fill(c.primary, opacity: o))
    ..drawCircle(Offset.zero, 4.5, stroke(c.onPrimary, width: 2, opacity: o))
    ..restore();
}

/// Recepti bez ijednog recepta: sveska se otvori, list se prelista, a
/// olovka napiše prvi red i spusti se pored.
class EmptyCookbook extends StatelessWidget {
  const EmptyCookbook({super.key});

  @override
  Widget build(BuildContext context) => const EmptyArt(
    label: 'Prazna kuvarica',
    duration: Duration(milliseconds: 2400),
    fit: 0.95,
    scene: _cookbook,
  );
}

const _pageRadius = Radius.circular(8);
const _spine = 100.0;
const _pageWidth = 68.0;

/// Stranica okrenuta oko hrbata: [k] = kosinus ugla (1 desno, -1 levo).
/// Menja se samo širina; zaobljenje uglova je uvek isto.
RRect _turned(double k) {
  final w = math.max(0.01, _pageWidth * k.abs());
  final r = math.min(_pageRadius.x, w / 2);
  return RRect.fromRectAndRadius(
    Rect.fromLTWH(k >= 0 ? _spine : _spine - w, 56, w, 100),
    Radius.circular(r),
  );
}

final Path _ink = Path()
  ..moveTo(110, 84)
  ..cubicTo(115, 75, 119, 93, 124, 84)
  ..cubicTo(129, 75, 133, 93, 138, 84)
  ..cubicTo(143, 75, 147, 93, 152, 84);

void _cookbook(Canvas canvas, double t, EmptyArtColors c) {
  final o = easeInOut(interval(t, 0, 0.34));
  canvas
    ..save()
    ..translate(-34 * (1 - o), 0);

  final left = RRect.fromRectAndRadius(
    const Rect.fromLTWH(32, 56, _pageWidth, 100),
    _pageRadius,
  );
  final right = RRect.fromRectAndRadius(
    const Rect.fromLTWH(_spine, 56, _pageWidth, 100),
    _pageRadius,
  );
  // Leva strana postoji tek kad korice legnu: dok se okreću, njihova
  // unutrašnjost je ta strana, pa se ništa ne pojavljuje pre njih.
  final lo = o >= 1 ? 1.0 : 0.0;
  canvas
    ..drawRRect(left, fill(c.surface, opacity: lo))
    ..drawRRect(left, stroke(c.line, opacity: lo))
    ..drawRRect(right, fill(c.surface))
    ..drawRRect(right, stroke(c.line));

  final ro = easeOut(interval(t, 0.3, 0.45));
  final rules = Path();
  for (final (x0, x1, y) in [
    (110.0, 158.0, 102.0),
    (110.0, 158.0, 118.0),
    (110.0, 150.0, 134.0),
    if (lo > 0) ...[
      (42.0, 90.0, 86.0),
      (42.0, 90.0, 102.0),
      (42.0, 82.0, 118.0),
    ],
  ]) {
    rules
      ..moveTo(x0, y)
      ..lineTo(x1, y);
  }
  canvas.drawPath(rules, stroke(c.softLine, width: 2.5, opacity: ro));

  // List koji se prelista.
  final fp = interval(t, 0.38, 0.6);
  if (fp > 0 && fp < 1) {
    final page = _turned(math.cos(math.pi * easeInOut(fp)));
    canvas
      ..drawRRect(page, fill(c.surface))
      ..drawRRect(page, stroke(c.line));
  }

  // Korice: spolja u boji teme, iznutra kao stranica.
  if (o < 1) {
    final k = math.cos(math.pi * o);
    final cover = _turned(k);
    canvas
      ..drawRRect(cover, fill(k > 0 ? c.primary : c.surface))
      ..drawRRect(cover, stroke(c.line));
  }
  canvas.drawLine(
    const Offset(_spine, 56),
    const Offset(_spine, 156),
    stroke(c.line),
  );

  // Olovka ispisuje prvi red.
  final metric = _ink.computeMetrics().first;
  final w = easeInOut(interval(t, 0.62, 0.9));
  if (w > 0) {
    canvas.drawPath(
      metric.extractPath(0, metric.length * w),
      stroke(c.primary),
    );
  }
  canvas.restore();

  final appear = interval(t, 0.55, 0.64);
  if (appear == 0) return;
  canvas.save();
  if (t < 0.92) {
    final pt =
        metric.getTangentForOffset(metric.length * w)?.position ??
        const Offset(110, 84);
    canvas
      ..translate(pt.dx, pt.dy - 2 - 14 * (1 - appear))
      ..rotate(deg(-40));
  } else {
    final r = easeOut(interval(t, 0.92, 1));
    canvas
      ..translate(152 + 6 * r, 82 + 58 * r)
      ..rotate(deg(-40 + 40 * r));
  }
  final body = Path()
    ..moveTo(0, 0)
    ..lineTo(5, -9)
    ..lineTo(33, -9)
    ..lineTo(33, 9)
    ..lineTo(5, 9)
    ..close();
  final tip = Path()
    ..moveTo(0, 0)
    ..lineTo(5, -9)
    ..lineTo(5, 9)
    ..close();
  canvas
    ..drawPath(body, fill(c.surface, opacity: appear))
    ..drawPath(body, stroke(c.line, width: 2.5, opacity: appear))
    ..drawPath(tip, fill(c.primary, opacity: appear))
    ..drawLine(
      const Offset(25, -9),
      const Offset(25, 9),
      stroke(c.line, width: 2.5, opacity: appear),
    )
    ..restore();
}
