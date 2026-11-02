import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tavli_palette.dart';
import '../../app/theme/theme_controller.dart';
import '../../domain/theme_choice.dart';

/// Profil → Izgled: stvarni primer boja i režim prilagođen veličini teksta.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeControllerProvider);
    final theme = Theme.of(context);
    Future<void> set(ThemeChoice next) async {
      final saved = await ref.read(themeControllerProvider.notifier).set(next);
      if (!saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izgled nije sačuvan. Pokušaj ponovo.')),
        );
      }
    }

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
                  Text('Režim', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final largeText =
                          MediaQuery.textScalerOf(context).scale(16) > 20;
                      if (constraints.maxWidth < 360 || largeText) {
                        return RadioGroup<AppThemeMode>(
                          groupValue: choice.mode,
                          onChanged: (mode) {
                            if (mode != null) {
                              unawaited(set(choice.copyWith(mode: mode)));
                            }
                          },
                          child: Column(
                            children: [
                              for (final mode in AppThemeMode.values)
                                RadioListTile<AppThemeMode>(
                                  value: mode,
                                  title: Text(mode.label),
                                  secondary: Icon(_modeIcon(mode)),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }
                      return SegmentedButton<AppThemeMode>(
                        showSelectedIcon: false,
                        segments: [
                          for (final mode in AppThemeMode.values)
                            ButtonSegment(
                              value: mode,
                              label: Text(mode.label),
                              icon: Icon(_modeIcon(mode)),
                            ),
                        ],
                        selected: {choice.mode},
                        onSelectionChanged: (modes) =>
                            set(choice.copyWith(mode: modes.first)),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text('Tema', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final largeText =
                          MediaQuery.textScalerOf(context).scale(16) > 20;
                      final columns = constraints.maxWidth >= 600 && !largeText
                          ? 3
                          : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final t in TavliTheme.values)
                            SizedBox(
                              width: width,
                              child: _ThemeCard(
                                theme: t,
                                selected: t == choice.theme,
                                onTap: () => set(choice.copyWith(theme: t)),
                              ),
                            ),
                        ],
                      );
                    },
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

IconData _modeIcon(AppThemeMode mode) => switch (mode) {
  AppThemeMode.light => Icons.light_mode_outlined,
  AppThemeMode.dark => Icons.dark_mode_outlined,
  AppThemeMode.system => Icons.brightness_auto_outlined,
};

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
    return Semantics(
      button: true,
      selected: selected,
      label: theme.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: p.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected
                ? current.colorScheme.primary
                : current.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        theme.label,
                        style: current.textTheme.titleMedium?.copyWith(
                          color: p.text,
                        ),
                      ),
                    ),
                    if (selected) Icon(Icons.check_circle, color: p.primary),
                  ],
                ),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: p.tints.first,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Icon(
                                  Icons.soup_kitchen_outlined,
                                  color: p.onContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recept',
                                    style: current.textTheme.labelSmall
                                        ?.copyWith(color: p.muted),
                                  ),
                                  Text(
                                    'Pasta sa povrćem',
                                    style: current.textTheme.titleSmall
                                        ?.copyWith(color: p.text),
                                  ),
                                  Text(
                                    '20 min',
                                    style: current.textTheme.bodySmall
                                        ?.copyWith(color: p.muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: p.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              'Otvori recept',
                              textAlign: TextAlign.center,
                              style: current.textTheme.labelLarge?.copyWith(
                                color: p.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
