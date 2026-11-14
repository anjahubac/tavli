import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:material_ui/material_ui.dart';

import '../theme/tavli_colors.dart';
import '../theme/tavli_status_colors.dart';
import 'motion.dart';

/// Polje za štikliranje sastojka: kvačica se iscrtava.
class AnimatedCheckmark extends StatelessWidget {
  const AnimatedCheckmark({super.key, required this.checked, this.size = 24});

  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final boxLine = TavliColors.of(context).boxLine;
    return TweenAnimationBuilder<double>(
      key: ValueKey(reduceMotion(context)),
      tween: Tween(end: checked ? 1 : 0),
      duration: TavliMotion.duration(context, TavliMotion.feedback),
      curve: Curves.easeOut,
      builder: (context, t, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: CheckPainter(
            t,
            fill: TavliStatusColors.of(context).success.foreground,
            mark: TavliStatusColors.of(context).success.background,
            border: boxLine,
          ),
        ),
      ),
    );
  }
}

class CheckPainter extends CustomPainter {
  CheckPainter(
    this.t, {
    required this.fill,
    required this.mark,
    required this.border,
  });

  final double t;
  final Color fill;
  final Color mark;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final box = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(s / 3),
    );
    final fillT = interval(t, 0, 0.4);
    canvas.drawRRect(
      box.deflate(1),
      Paint()
        ..color = Color.lerp(border, fill, fillT)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (fillT > 0) {
      canvas.drawRRect(box, Paint()..color = fill.withValues(alpha: fillT));
    }
    final draw = interval(t, 0.3, 1);
    if (draw <= 0) return;
    final path = Path()
      ..moveTo(s * 0.22, s * 0.52)
      ..lineTo(s * 0.42, s * 0.71)
      ..lineTo(s * 0.79, s * 0.3);
    final partial = Path();
    for (final PathMetric m in path.computeMetrics()) {
      partial.addPath(m.extractPath(0, m.length * draw), Offset.zero);
    }
    canvas.drawPath(
      partial,
      Paint()
        ..color = mark
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(CheckPainter old) =>
      old.t != t ||
      old.fill != fill ||
      old.mark != mark ||
      old.border != border;
}

/// Bedž sa brojem koji "poskoči" kad se broj poveća.
class BumpBadge extends StatefulWidget {
  const BumpBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  State<BumpBadge> createState() => _BumpBadgeState();
}

class _BumpBadgeState extends State<BumpBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: TavliMotion.transition,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void didUpdateWidget(BumpBadge old) {
    super.didUpdateWidget(old);
    if (widget.count > old.count && !reduceMotion(context)) {
      unawaited(_c.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => Badge(
      isLabelVisible: widget.count > 0,
      label: Transform.scale(
        scale: 1 + 0.08 * math.sin(math.pi * _c.value),
        child: Text('${widget.count}'),
      ),
      child: Transform.scale(
        scale: 1 + 0.05 * math.sin(math.pi * _c.value),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

/// Mali čip sa nazivom sastojka leti od [from] do [to] (npr. ikone taba
/// "Kupovina"). Sa smanjenim kretanjem ne leti ništa.
Future<void> flyChipToTarget({
  required BuildContext context,
  required GlobalKey from,
  required GlobalKey to,
  required String label,
}) async {
  if (reduceMotion(context)) return;
  final overlay = Overlay.maybeOf(context);
  final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
  final fromBox = from.currentContext?.findRenderObject() as RenderBox?;
  final toBox = to.currentContext?.findRenderObject() as RenderBox?;
  if (overlay == null ||
      overlayBox == null ||
      fromBox == null ||
      toBox == null) {
    return;
  }
  Offset center(RenderBox b) =>
      b.localToGlobal(b.size.center(Offset.zero), ancestor: overlayBox);
  final done = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyingChip(
      start: center(fromBox),
      end: center(toBox),
      label: label,
      onDone: () {
        entry.remove();
        done.complete();
      },
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class _FlyingChip extends StatefulWidget {
  const _FlyingChip({
    required this.start,
    required this.end,
    required this.label,
    required this.onDone,
  });

  final Offset start;
  final Offset end;
  final String label;
  final VoidCallback onDone;

  @override
  State<_FlyingChip> createState() => _FlyingChipState();
}

class _FlyingChipState extends State<_FlyingChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: TavliMotion.transition,
  );

  bool _finished = false;

  @override
  void initState() {
    super.initState();
    unawaited(_c.forward().whenComplete(_finish));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_c.value);
                // Luk: kontrolna tačka iznad prave linije.
                final control = Offset(
                  (widget.start.dx + widget.end.dx) / 2,
                  math.min(widget.start.dy, widget.end.dy) - 80,
                );
                final p =
                    widget.start * ((1 - t) * (1 - t)) +
                    control * (2 * (1 - t) * t) +
                    widget.end * (t * t);
                return Positioned(
                  left: p.dx,
                  top: p.dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: Opacity(
                      opacity: 1 - interval(_c.value, 0.8, 1),
                      child: Transform.scale(scale: 1 - 0.55 * t, child: child),
                    ),
                  ),
                );
              },
              child: Material(
                color: colors.primary,
                shape: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: colors.onPrimary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
