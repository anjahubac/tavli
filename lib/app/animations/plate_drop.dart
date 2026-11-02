import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

/// Plan obroka: recept dodat u dan sleti na tanjir u kalendaru.
/// Igra jednom; završna slika je recept na tanjiru.
class PlatePlanDrop extends StatelessWidget {
  const PlatePlanDrop({
    super.key,
    this.day = 'Sreda',
    this.recipe = 'Sarma',
    this.width = 160,
  });

  final String day;
  final String recipe;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final height = width * 1.1;
    return Semantics(
      label: 'Recept na tanjiru',
      excludeSemantics: true,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: MotionBuilder(
          repeat: false,
          duration: const Duration(milliseconds: 1500),
          builder: (context, t, _) {
            final fall = Curves.easeIn.transform(interval(t, 0, 0.45));
            final land = interval(t, 0.45, 0.7);
            final squash = math.sin(math.pi * land);
            final plateY = height * 0.62;
            final itemY = -40 + (plateY - 12 + 40) * fall;
            return Stack(
              children: [
                Positioned(
                  left: 14,
                  top: 12,
                  child: Text(
                    day,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: plateY - 22,
                  child: Center(
                    child: Transform.scale(
                      scaleX: 1 + 0.06 * squash,
                      scaleY: 1 - 0.06 * squash,
                      child: CustomPaint(
                        size: Size(width * 0.72, 44),
                        painter: _PlatePainter(
                          rim: colors.outlineVariant,
                          plate: colors.surfaceContainer,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: itemY - 16,
                  child: Center(
                    child: Opacity(
                      opacity: interval(t, 0, 0.1),
                      child: Transform.rotate(
                        angle: (1 - fall) * -0.3,
                        child: Transform.scale(
                          scaleX: 1 + 0.12 * squash,
                          scaleY: 1 - 0.12 * squash,
                          child: _Dish(recipe),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Dish extends StatelessWidget {
  const _Dish(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.primary,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant, size: 16, color: colors.onPrimary),
            const SizedBox(width: 6),
            Text(
              name,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: colors.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  _PlatePainter({required this.rim, required this.plate});

  final Color rim;
  final Color plate;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    canvas.drawOval(outer, Paint()..color = plate);
    canvas.drawOval(
      outer,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawOval(
      outer.deflate(size.height * 0.22),
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.rim != rim || old.plate != plate;
}
