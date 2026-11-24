import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import 'empty_art.dart';

/// Poruke dok AI pravi recept.
const cookingMessages = [
  'Seckam luk…',
  'Dodajem začine…',
  'Mešam…',
  'Probam da li je slano…',
];

/// Lonac koji krčka (para i mehurići) i poruke koje se smenjuju.
class SimmeringPot extends StatefulWidget {
  const SimmeringPot({
    super.key,
    this.messages = cookingMessages,
    this.size = 140,
    this.interval = const Duration(milliseconds: 1800),
  });

  final List<String> messages;
  final double size;
  final Duration interval;

  @override
  State<SimmeringPot> createState() => _SimmeringPotState();
}

class _SimmeringPotState extends State<SimmeringPot> {
  Timer? _timer;
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        reduceMotion(context) || !TickerMode.valuesOf(context).enabled;
    if (still) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(widget.interval, (_) {
        if (mounted) setState(() => _index++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = EmptyArtColors.of(Theme.of(context).colorScheme);
    final message = widget.messages.isEmpty
        ? null
        : widget.messages[_index % widget.messages.length];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MotionBuilder(
          duration: const Duration(milliseconds: 2400),
          restValue: 0.12,
          builder: (context, t, still) => MotionCanvas(
            size: widget.size,
            design: 200,
            label: 'Lonac koji krčka',
            painter: EmptyArtPainter(t, art, simmeringPot),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          AnimatedSwitcher(
            key: ValueKey(reduceMotion(context)),
            duration: TavliMotion.duration(context, TavliMotion.feedback),
            child: Text(
              message,
              key: ValueKey(message),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ],
    );
  }
}

/// Lonac na ringli u linijskom stilu (koordinate 200×200): poklopac
/// povremeno poskoči, para se diže, plamen treperi.
void simmeringPot(Canvas canvas, double t, EmptyArtColors c) {
  // Plamen.
  for (var i = 0; i < 3; i++) {
    final x = 80.0 + i * 20;
    final s = 0.85 + 0.15 * math.sin(t * math.pi * 6 + i * 2);
    canvas
      ..save()
      ..translate(x, 172)
      ..scale(1, s)
      ..drawPath(
        Path()
          ..quadraticBezierTo(-6, -8, 0, -16)
          ..quadraticBezierTo(6, -8, 0, 0)
          ..close(),
        fill(c.primary),
      )
      ..restore();
  }
  canvas
    ..drawLine(const Offset(66, 172), const Offset(134, 172), stroke(c.line))
    ..drawPath(
      Path()
        ..moveTo(60, 112)
        ..lineTo(48, 112)
        ..moveTo(140, 112)
        ..lineTo(152, 112),
      stroke(c.line, width: 4),
    );
  final body = Path()
    ..moveTo(60, 102)
    ..lineTo(60, 140)
    ..quadraticBezierTo(60, 156, 76, 156)
    ..lineTo(124, 156)
    ..quadraticBezierTo(140, 156, 140, 140)
    ..lineTo(140, 102);
  canvas
    ..drawPath(body, fill(c.surface))
    ..drawPath(body, stroke(c.line))
    ..drawPath(
      Path()
        ..moveTo(66, 124)
        ..quadraticBezierTo(83, 118, 100, 124)
        ..quadraticBezierTo(117, 130, 134, 124),
      stroke(c.softLine, width: 2.5),
    );

  // Poklopac.
  final jig = math.pow(math.max(0, math.sin(t * math.pi * 4)), 6).toDouble();
  canvas
    ..save()
    ..translate(0, -5 * jig)
    ..translate(100, 100)
    ..rotate(deg(3 * jig * math.sin(t * math.pi * 8)))
    ..translate(-100, -100);
  final lid = Path()
    ..moveTo(54, 102)
    ..quadraticBezierTo(100, 84, 146, 102)
    ..close();
  canvas
    ..drawPath(lid, fill(c.surface))
    ..drawPath(lid, stroke(c.line))
    ..drawCircle(const Offset(100, 88), 4.5, fill(c.surface))
    ..drawCircle(const Offset(100, 88), 4.5, stroke(c.line))
    ..restore();

  // Para: tri talasaste linije koje se dižu i blede.
  for (var i = 0; i < 3; i++) {
    final x = 78.0 + i * 22;
    final ph = (t + i / 3) % 1;
    final path = Path()
      ..moveTo(x, 78)
      ..relativeQuadraticBezierTo(-7, -8, 0, -16)
      ..relativeQuadraticBezierTo(7, -8, 0, -16)
      ..relativeQuadraticBezierTo(-7, -8, 0, -16);
    for (final metric in path.computeMetrics()) {
      final l = metric.length;
      final start = l * (0.45 - 1.45 * ph);
      final a = math.max(0.0, start);
      final b = math.min(l, start + 0.45 * l);
      if (b <= a) continue;
      canvas.drawPath(
        metric.extractPath(a, b),
        stroke(c.primary, opacity: math.sin(math.pi * ph) * 0.9),
      );
    }
  }
}
