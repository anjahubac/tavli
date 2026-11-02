import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

/// Poruke dok AI pravi recept.
const cookingMessages = [
  'Seckam luk…',
  'Dodajem začine…',
  'Mešam…',
  'Probam da li je slano…',
];

const _flame = Color(0xFFF08A24);
const _flameCore = Color(0xFFFFC94A);

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
    final still = reduceMotion(context);
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
    final colors = Theme.of(context).colorScheme;
    final message = widget.messages.isEmpty
        ? null
        : widget.messages[_index % widget.messages.length];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MotionBuilder(
          duration: const Duration(milliseconds: 2400),
          restValue: 0.3,
          builder: (context, t, still) => MotionCanvas(
            size: widget.size,
            design: 200,
            label: 'Lonac koji krčka',
            painter: PotPainter(
              t,
              pot: colors.primary,
              potShade: colors.onPrimaryContainer,
              liquid: colors.primaryContainer,
              steam: colors.onSurfaceVariant,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
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

/// Lonac na ringli: mehurići, para, plamen (koordinate 200×200).
class PotPainter extends CustomPainter {
  PotPainter(
    this.t, {
    required this.pot,
    required this.potShade,
    required this.liquid,
    required this.steam,
  });

  final double t;
  final Color pot;
  final Color potShade;
  final Color liquid;
  final Color steam;

  @override
  void paint(Canvas canvas, Size size) {
    // Para: tri talasaste linije koje se dižu i blede.
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      final x = 70.0 + i * 30;
      final path = Path()..moveTo(x, 92 - p * 40);
      for (var k = 1; k <= 4; k++) {
        path.quadraticBezierTo(
          x + (k.isOdd ? 8 : -8),
          92 - p * 40 - k * 9 + 4.5,
          x,
          92 - p * 40 - k * 9,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = steam.withValues(alpha: 0.55 * math.sin(p * math.pi))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    // Telo lonca i drške.
    final body = RRect.fromLTRBAndCorners(
      40,
      100,
      160,
      164,
      bottomLeft: const Radius.circular(22),
      bottomRight: const Radius.circular(22),
    );
    final handle = Paint()
      ..color = potShade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(26, 112), const Offset(40, 112), handle);
    canvas.drawLine(const Offset(160, 112), const Offset(174, 112), handle);
    canvas.drawRRect(body, Paint()..color = pot);
    // Površina jela.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 101), width: 120, height: 18),
      Paint()..color = liquid,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(34, 94, 166, 102, const Radius.circular(4)),
      Paint()..color = potShade,
    );

    // Mehurići na površini.
    for (final (x, phase, r) in const [
      (72.0, 0.0, 5.0),
      (100.0, 0.45, 6.0),
      (126.0, 0.75, 4.5),
    ]) {
      final p = (t * 2 + phase) % 1;
      final rise = p * 18;
      canvas.drawCircle(
        Offset(x, 96 - rise),
        r * (0.6 + 0.4 * p),
        Paint()
          ..color = liquid.withValues(alpha: 1 - p * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Plamen ispod lonca.
    for (var i = 0; i < 3; i++) {
      final x = 76.0 + i * 24;
      final flicker = 1 + 0.15 * math.sin((t * 6 + i * 0.7) * 2 * math.pi);
      final h = 16 * flicker;
      final flame = Path()
        ..moveTo(x - 7, 184)
        ..quadraticBezierTo(x - 6, 184 - h, x, 184 - h * 1.4)
        ..quadraticBezierTo(x + 6, 184 - h, x + 7, 184)
        ..close();
      canvas.drawPath(flame, Paint()..color = _flame);
      canvas.drawCircle(Offset(x, 180), 3, Paint()..color = _flameCore);
    }
  }

  @override
  bool shouldRepaint(PotPainter old) => old.t != t || old.pot != pot;
}
