import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

/// Scena sa odobrenog Superdesign platna. Resursi su izvezeni u koordinatama
/// kruga 640 × 640, pa se zajedno skaliraju za telefon i računar.
class IntroSkillet extends StatelessWidget {
  const IntroSkillet({super.key});

  static const _scene = 640.0;
  static const _rim = 371.0;
  static const _length = 4200;
  static const _pan = _Artwork('pan', Rect.fromLTWH(88, 333, 461, 170));
  static const _steam = [
    _Artwork('steam-1', Rect.fromLTWH(192, 245, 45, 97)),
    _Artwork('steam-2', Rect.fromLTWH(269, 206, 63, 134)),
  ];

  static const _ingredients = {
    TavliMotif.bosiljak: [
      _Ingredient('bosiljak-1', Rect.fromLTWH(165, 41, 67, 66), 100, -15, 10),
      _Ingredient('bosiljak-2', Rect.fromLTWH(218, 61, 65, 39), 400, 20, -10),
      _Ingredient('bosiljak-3', Rect.fromLTWH(282, 47, 51, 67), 700, -5, 25),
    ],
    TavliMotif.safran: [
      _Ingredient('safran-1', Rect.fromLTWH(194, 41, 117, 134), 200, 0, 0),
      _Ingredient(
        'safran-2',
        Rect.fromLTWH(281, 41, 80, 80),
        480,
        -12,
        9,
        drift: -42,
      ),
    ],
    TavliMotif.borovnica: [
      _Ingredient('borovnica-1', Rect.fromLTWH(172, 41, 65, 68), 100, 10, -5),
      _Ingredient('borovnica-2', Rect.fromLTWH(262, 41, 58, 61), 400, -20, 15),
      _Ingredient('borovnica-3', Rect.fromLTWH(228, 41, 49, 49), 700, 5, -15),
      _Ingredient('borovnica-4', Rect.fromLTWH(161, 41, 43, 42), 1000, -12, 8),
      _Ingredient('borovnica-5', Rect.fromLTWH(310, 41, 33, 33), 1300, 15, -5),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final motif = TavliColors.of(context).motif;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 256),
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipOval(
          child: ColoredBox(
            color: colors.primaryContainer,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = constraints.maxWidth / _scene;
                return MotionBuilder(
                  duration: const Duration(milliseconds: _length),
                  repeat: false,
                  builder: (context, t, still) {
                    final time = t * _length;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (!still)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: _rim * scale,
                            child: ClipRect(
                              child: Stack(
                                children: [
                                  for (final ingredient in _ingredients[motif]!)
                                    ingredient.fall(time, scale),
                                ],
                              ),
                            ),
                          ),
                        _pan.place(scale, color: colors.primary),
                        for (final (index, curl) in _steam.indexed)
                          _risingSteam(
                            curl,
                            time,
                            delay: 2800 + 200 * index,
                            scale: scale,
                            color: colors.onPrimaryContainer,
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _risingSteam(
    _Artwork artwork,
    double time, {
    required int delay,
    required double scale,
    required Color color,
  }) {
    final progress = Curves.easeOutCubic.transform(
      ((time - delay) / 1200).clamp(0.0, 1.0),
    );
    return artwork.place(
      scale,
      color: color,
      offset: Offset(0, 32 * (1 - progress)),
      opacity: progress,
    );
  }
}

class _Artwork {
  const _Artwork(this.name, this.bounds);

  final String name;
  final Rect bounds;

  Widget place(
    double scale, {
    Color? color,
    Offset offset = Offset.zero,
    double opacity = 1,
    double angle = 0,
  }) {
    final rect = Rect.fromLTWH(
      (bounds.left + offset.dx) * scale,
      (bounds.top + offset.dy) * scale,
      bounds.width * scale,
      bounds.height * scale,
    );
    return Positioned.fromRect(
      rect: rect,
      child: Transform.rotate(
        angle: angle,
        child: Image.asset(
          'assets/branding/intro/$name.png',
          color: color,
          opacity: AlwaysStoppedAnimation(opacity),
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class _Ingredient extends _Artwork {
  const _Ingredient(
    super.name,
    super.bounds,
    this.delay,
    this.startAngle,
    this.endAngle, {
    this.drift = 0,
  });

  final int delay;
  final double startAngle;
  final double endAngle;
  final double drift;

  Widget fall(double time, double scale) {
    final progress = ((time - delay) / 1400).clamp(0.0, 1.0);
    final travel = Curves.easeInOutCubic.transform(progress);
    return place(
      scale,
      offset: Offset(drift * travel, 362 * travel),
      angle: (startAngle + (endAngle - startAngle) * travel) * math.pi / 180,
      opacity: interval(progress, 0, 0.1) * (1 - interval(progress, 0.85, 1)),
    );
  }
}
