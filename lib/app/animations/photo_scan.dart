import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

/// Fotografija recepta: dok AI čita, preko nje prelaze uglovi „tražila“ i
/// linija skeniranja (bez natpisa ispod slike);
/// prepoznati sastojci zatim iskaču jedan po jedan kao čipovi.
class PhotoScan extends StatelessWidget {
  const PhotoScan({
    super.key,
    required this.photo,
    required this.scanning,
    this.ingredients = const [],
    this.height = 260,
  });

  final Widget photo;
  final bool scanning;

  /// Prepoznati sastojci (prazno dok AI radi).
  final List<String> ingredients;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Skeniranje fotografije',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photo,
                  if (scanning)
                    MotionBuilder(
                      duration: const Duration(milliseconds: 2200),
                      restValue: 0.5,
                      builder: (context, t, _) => CustomPaint(
                        painter: ScanLinePainter(t, color: colors.primary),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!scanning && ingredients.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PoppingChips(ingredients),
        ],
      ],
    );
  }
}

class _PoppingChips extends StatelessWidget {
  const _PoppingChips(this.names);

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return MotionBuilder(
      repeat: false,
      duration: TavliMotion.reveal,
      builder: (context, t, _) => Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final (i, name) in names.indexed)
            Builder(
              builder: (context) {
                final start = names.length <= 1
                    ? 0.0
                    : i / (names.length - 1) * 0.3;
                final local = interval(t, start, start + 0.7);
                return Opacity(
                  opacity: local.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: Curves.easeOut.transform(local),
                    child: Chip(label: Text(name)),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Svetla traka sa linijom koja ide gore-dole preko slike.
class ScanLinePainter extends CustomPainter {
  ScanLinePainter(this.t, {required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Gore pa dole, glatko.
    final p = Curves.easeInOut.transform(t < 0.5 ? t * 2 : 2 - t * 2);
    final y = size.height * p;
    final down = t < 0.5;
    final band = Rect.fromLTRB(
      0,
      down ? y - 60 : y,
      size.width,
      down ? y : y + 60,
    );
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: down ? Alignment.topCenter : Alignment.bottomCenter,
          end: down ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.28)],
        ).createShader(band),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = color
        ..strokeWidth = 3,
    );
    _corners(canvas, size);
  }

  /// Uglovi „tražila“ u boji teme, blago pulsiraju.
  void _corners(Canvas canvas, Size size) {
    const inset = 14.0;
    const len = 24.0;
    const r = 8.0;
    final pulse = 0.75 + 0.25 * math.sin(t * 2 * math.pi);
    final paint = Paint()
      ..color = color.withValues(alpha: pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width - inset;
    final h = size.height - inset;
    final path = Path()
      ..moveTo(inset, inset + len)
      ..lineTo(inset, inset + r)
      ..quadraticBezierTo(inset, inset, inset + r, inset)
      ..lineTo(inset + len, inset)
      ..moveTo(w - len, inset)
      ..lineTo(w - r, inset)
      ..quadraticBezierTo(w, inset, w, inset + r)
      ..lineTo(w, inset + len)
      ..moveTo(w, h - len)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(w - len, h)
      ..moveTo(inset + len, h)
      ..lineTo(inset + r, h)
      ..quadraticBezierTo(inset, h, inset, h - r)
      ..lineTo(inset, h - len);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ScanLinePainter old) => old.t != t || old.color != color;
}
