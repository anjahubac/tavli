import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tavli_palette.dart';
import '../../app/theme/theme_controller.dart';
import '../../domain/theme_choice.dart';

/// Profil → Izgled: tema (Bosiljak, Šafran, Borovnica) i režim.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);
    final theme = Theme.of(context);
    void set(ThemeChoice c) => unawaited(controller.set(c));

    return Scaffold(
      appBar: AppBar(title: const Text('Izgled')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Tema', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final t in TavliTheme.values)
                        _ThemeCard(
                          theme: t,
                          selected: t == choice.theme,
                          onTap: () => set(choice.copyWith(theme: t)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text('Režim', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SegmentedButton<AppThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      for (final m in AppThemeMode.values)
                        ButtonSegment(
                          value: m,
                          label: Text(m.label),
                          icon: Icon(switch (m) {
                            AppThemeMode.light => Icons.light_mode_outlined,
                            AppThemeMode.dark => Icons.dark_mode_outlined,
                            AppThemeMode.system =>
                              Icons.brightness_auto_outlined,
                          }),
                        ),
                    ],
                    selected: {choice.mode},
                    onSelectionChanged: (s) =>
                        set(choice.copyWith(mode: s.first)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartica teme sa pregledom boja u trenutnoj osvetljenosti.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final TavliTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = Theme.of(context);
    final p = TavliPalette.of(theme, current.brightness);
    final colors = current.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: theme.label,
      excludeSemantics: true,
      child: SizedBox(
        width: 150,
        child: Material(
          color: p.bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Dot(p.primary),
                      _Dot(p.container),
                      _Dot(p.tints[0]),
                      const Spacer(),
                      if (selected)
                        Icon(Icons.check_circle, color: colors.primary),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: p.line),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: p.primary,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    theme.label,
                    style: current.textTheme.titleMedium?.copyWith(
                      color: p.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    margin: const EdgeInsets.only(right: 4),
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );
}
