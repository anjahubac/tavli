import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import 'empty_art.dart';

/// Povlačenje nadole za osvežavanje: umesto točkića varjača meša u loncu
/// (pogled odozgo).
class SpoonRefresh extends StatefulWidget {
  const SpoonRefresh({super.key, required this.onRefresh, required this.child});

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  State<SpoonRefresh> createState() => _SpoonRefreshState();
}

class _SpoonRefreshState extends State<SpoonRefresh> {
  RefreshIndicatorStatus? _status;

  bool get _visible =>
      _status != null &&
      _status != RefreshIndicatorStatus.done &&
      _status != RefreshIndicatorStatus.canceled;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator.noSpinner(
          onRefresh: widget.onRefresh,
          onStatusChange: (s) => setState(() => _status = s),
          semanticsLabel: 'Osvežavam',
          child: widget.child,
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              key: ValueKey(reduceMotion(context)),
              opacity: _visible ? 1 : 0,
              duration: TavliMotion.duration(context, TavliMotion.feedback),
              child: _visible
                  ? Center(
                      child: SpoonPot(
                        stirring:
                            _status == RefreshIndicatorStatus.refresh ||
                            _status == RefreshIndicatorStatus.snap,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Lonac gledan odozgo u kome varjača kruži; mala okrugla značka za
/// osvežavanje.
class SpoonPot extends StatelessWidget {
  const SpoonPot({super.key, this.stirring = true, this.size = 64});

  final bool stirring;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = EmptyArtColors.of(Theme.of(context).colorScheme);
    return MotionBuilder(
      duration: const Duration(milliseconds: 1500),
      restValue: 0.1,
      play: stirring,
      builder: (context, t, _) => MotionCanvas(
        size: size,
        design: 200,
        label: 'Varjača u loncu',
        painter: EmptyArtPainter(t, colors, stirringPot),
      ),
    );
  }
}

/// Lonac odozgo, varjača i spirala u čorbi (koordinate 200×200).
void stirringPot(Canvas canvas, double t, EmptyArtColors c) {
  const center = Offset(100, 104);
  final a = t * 2 * math.pi;
  canvas
    ..drawPath(
      Path()
        ..moveTo(52, 104)
        ..lineTo(40, 104)
        ..moveTo(148, 104)
        ..lineTo(160, 104),
      stroke(c.line, width: 5),
    )
    ..drawCircle(center, 50, fill(c.surface))
    ..drawCircle(center, 50, stroke(c.line))
    ..drawCircle(center, 40, fill(c.tint))
    ..drawCircle(center, 40, stroke(c.softLine, width: 2.5));

  // Spirala u čorbi se okreće zajedno sa varjačom.
  final swirl = Path()
    ..moveTo(100, 94)
    ..arcToPoint(const Offset(90, 104), radius: const Radius.circular(10))
    ..arcToPoint(
      const Offset(110, 124),
      radius: const Radius.circular(20),
      largeArc: true,
    )
    ..arcToPoint(const Offset(80, 94), radius: const Radius.circular(30));
  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..rotate(a)
    ..translate(-center.dx, -center.dy)
    ..drawPath(swirl, stroke(c.primary, opacity: 0.55))
    ..restore();

  // Varjača: drška i glava.
  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..rotate(a - deg(40))
    ..drawLine(
      const Offset(24, 0),
      const Offset(66, 0),
      stroke(c.primary, width: 6),
    )
    ..drawOval(
      Rect.fromCenter(center: const Offset(14, 0), width: 24, height: 16),
      fill(c.surface),
    )
    ..drawOval(
      Rect.fromCenter(center: const Offset(14, 0), width: 24, height: 16),
      stroke(c.primary),
    )
    ..restore();

  // Mehurići izranjaju.
  const bubbles = [Offset(80, 90), Offset(118, 120), Offset(112, 86)];
  for (final (i, b) in bubbles.indexed) {
    final p = (t * 2 + i / 3) % 1;
    canvas.drawCircle(
      b,
      2 + 3 * p,
      stroke(c.softLine, width: 2, opacity: math.sin(math.pi * p)),
    );
  }
}
