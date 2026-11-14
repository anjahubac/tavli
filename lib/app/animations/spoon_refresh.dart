import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'motion.dart';

const _wood = Color(0xFFB07A45);
const _woodDark = Color(0xFF8A5A2E);

/// Povlačenje nadole za osvežavanje: umesto točkića varjača meša u loncu.
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

/// Mali lonac u kome varjača kruži.
class SpoonPot extends StatelessWidget {
  const SpoonPot({super.key, this.stirring = true, this.size = 56});

  final bool stirring;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: CircleBorder(side: BorderSide(color: colors.outlineVariant)),
      child: MotionBuilder(
        duration: const Duration(milliseconds: 1100),
        restValue: 0.15,
        play: stirring,
        builder: (context, t, _) => MotionCanvas(
          size: size,
          design: 100,
          label: 'Varjača u loncu',
          painter: SpoonPotPainter(
            t,
            pot: colors.primary,
            soup: colors.primaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Koordinate 100×100.
class SpoonPotPainter extends CustomPainter {
  SpoonPotPainter(this.t, {required this.pot, required this.soup});

  final double t;
  final Color pot;
  final Color soup;

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    // Glava varjače kruži po površini (elipsa).
    final head = Offset(50 + 16 * math.cos(a), 52 + 5 * math.sin(a));
    final behind = math.sin(a) < 0;
    void spoon() {
      final handleEnd = Offset(head.dx + 18 + 6 * math.cos(a), 14);
      canvas.drawLine(
        head,
        handleEnd,
        Paint()
          ..color = _wood
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawOval(
        Rect.fromCenter(center: head, width: 14, height: 9),
        Paint()..color = _woodDark,
      );
    }

    if (behind) spoon();
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 52), width: 56, height: 16),
      Paint()..color = soup,
    );
    if (!behind) spoon();
    final body = Path()
      ..moveTo(20, 52)
      ..lineTo(80, 52)
      ..lineTo(76, 76)
      ..quadraticBezierTo(75, 84, 66, 84)
      ..lineTo(34, 84)
      ..quadraticBezierTo(25, 84, 24, 76)
      ..close();
    canvas.drawPath(body, Paint()..color = pot);
    canvas.drawRRect(
      RRect.fromLTRBR(16, 48, 84, 55, const Radius.circular(3)),
      Paint()..color = pot,
    );
  }

  @override
  bool shouldRepaint(SpoonPotPainter old) => old.t != t || old.pot != pot;
}
