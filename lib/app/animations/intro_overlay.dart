import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import 'intro_skillet.dart';

/// Uvodni ekran: motiv teme, naziv i podnaslov.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  static const _logoWidth = 112.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: TavliPalette.of(TavliMotif.bosiljak, theme.brightness).bg,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IntroSkillet(),
                const SizedBox(height: 28),
                Image.asset(
                  'assets/branding/tavli-wordmark.png',
                  width: _logoWidth,
                  fit: BoxFit.contain,
                  color: theme.colorScheme.onSurface,
                  semanticLabel: 'Tavli',
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
