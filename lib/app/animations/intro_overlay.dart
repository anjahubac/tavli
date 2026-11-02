import 'dart:async';

import 'package:flutter/material.dart';

import 'intro_motif.dart';

/// Kratak uvod pri pokretanju sa motivom aktivne teme; posle [hold] se
/// izgubi, a dodir ga preskače. Ne blokira aplikaciju: ispod je već učitana.
class IntroOverlay extends StatefulWidget {
  const IntroOverlay({
    super.key,
    required this.child,
    this.enabled = true,
    this.hold = const Duration(milliseconds: 1800),
  });

  final Widget child;
  final bool enabled;
  final Duration hold;

  @override
  State<IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<IntroOverlay> {
  late bool _shown = widget.enabled;
  bool _fading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_shown) _timer = Timer(widget.hold, _hide);
  }

  void _hide() {
    _timer?.cancel();
    if (mounted && !_fading) setState(() => _fading = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Uvek isti Stack, da aplikacija ispod ne krene ispočetka kad uvod nestane.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_shown)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _fading ? 0 : 1,
              duration: const Duration(milliseconds: 350),
              onEnd: () => setState(() => _shown = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hide,
                child: const IntroScreen(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Uvodni ekran: motiv teme, naziv i podnaslov.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, c) =>
                      IntroMotif(size: c.maxWidth.clamp(120, 260)),
                ),
                const SizedBox(height: 28),
                Text(
                  'Tavli',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recepti, plan obroka i kupovina na jednom mestu',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
