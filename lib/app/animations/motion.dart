import 'dart:async';

import 'package:flutter/material.dart';

/// Sistem traži smanjeno kretanje (iOS/macOS "Reduce motion",
/// Android "Remove animations").
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Kratke potvrde i prelazi; sadržaj nikad ne čeka dekorativnu animaciju.
abstract final class TavliMotion {
  static const feedback = Duration(milliseconds: 180);
  static const transition = Duration(milliseconds: 240);
  static const reveal = Duration(milliseconds: 360);

  static Duration duration(BuildContext context, Duration value) =>
      reduceMotion(context) ? Duration.zero : value;
}

/// Pokreće [builder] sa `t` od 0 do 1: u petlji ([repeat]) ili jednom.
/// Kad se traži smanjeno kretanje, kontroler ne radi i crta se samo
/// [restValue] — mirna, završna slika animacije.
class MotionBuilder extends StatefulWidget {
  const MotionBuilder({
    super.key,
    required this.duration,
    required this.builder,
    this.repeat = true,
    this.restValue = 1,
    this.play = true,
  });

  final Duration duration;
  final bool repeat;

  /// Slika kad se ne animira (smanjeno kretanje ili [play] = false).
  final double restValue;

  /// false: animacija stoji na [restValue] (npr. tajmer je pauziran).
  final bool play;
  final Widget Function(BuildContext context, double t, bool still) builder;

  @override
  State<MotionBuilder> createState() => _MotionBuilderState();
}

class _MotionBuilderState extends State<MotionBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MotionBuilder old) {
    super.didUpdateWidget(old);
    _c.duration = widget.duration;
    if (old.play != widget.play || old.repeat != widget.repeat) _sync();
  }

  void _sync() {
    _still = reduceMotion(context) || !widget.play;
    if (_still) {
      _c.stop();
      return;
    }
    if (_c.isAnimating) return;
    if (widget.repeat) {
      unawaited(_c.repeat());
    } else if (!_c.isCompleted) {
      unawaited(_c.forward());
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
    builder: (context, _) =>
        widget.builder(context, _still ? widget.restValue : _c.value, _still),
  );
}

/// Deo intervala [begin, end] u kome je `t`, sveden na 0..1.
double interval(double t, double begin, double end) =>
    ((t - begin) / (end - begin)).clamp(0.0, 1.0);

/// Slika na kvadratnoj površini veličine [size]; crtež je u koordinatama
/// [design]×[design] pa se samo skalira.
class MotionCanvas extends StatelessWidget {
  const MotionCanvas({
    super.key,
    required this.size,
    required this.painter,
    required this.label,
    this.design = 280,
  });

  final double size;
  final double design;
  final CustomPainter painter;

  /// Opis za čitač ekrana (srpski).
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: true,
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _Scaled(painter, size / design)),
      ),
    ),
  );
}

class _Scaled extends CustomPainter {
  _Scaled(this.inner, this.scale);

  final CustomPainter inner;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    inner.paint(canvas, size / scale);
    canvas.restore();
  }

  // Crtež se pravi iznova za svaki kadar animacije.
  @override
  bool shouldRepaint(_Scaled old) => true;
}
