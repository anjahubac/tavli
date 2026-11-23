import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/theme_controller.dart';
import '../../domain/theme_choice.dart';
import 'settings_page.dart';

/// Profil → Izgled: režim (svetla, tamna, kao sistem) i tri teme sa
/// stvarnim primerom boja.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeControllerProvider);
    Future<void> set(ThemeChoice next) async {
      final saved = await ref.read(themeControllerProvider.notifier).set(next);
      if (!saved && context.mounted) {
        showTavliMessage(context, 'Izgled nije sačuvan. Pokušaj ponovo.');
      }
    }

    final cards = [
      for (final t in TavliTheme.values)
        _ThemeCard(
          theme: t,
          selected: t == choice.theme,
          onTap: () => unawaited(set(choice.copyWith(theme: t))),
        ),
    ];
    final columns = isWideSettings(context) && !isLargeText(context);
    return SettingsPage(
      title: 'Izgled',
      backLabel: 'Profil',
      fallbackLocation: '/profile',
      children: [
        SettingsSection(
          title: 'Režim',
          children: [
            TavliChoice<AppThemeMode>.segmented(
              expand: true,
              options: [
                for (final mode in AppThemeMode.values)
                  TavliOption(mode, mode.label, glyph: _modeGlyph[mode]),
              ],
              selected: choice.mode,
              onChanged: (mode) => unawaited(set(choice.copyWith(mode: mode))),
            ),
          ],
        ),
        SettingsSection(
          title: 'Tema',
          children: [
            if (columns)
              TavliCardRow(spacing: TavliSpacing.medium, children: cards)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: TavliSpacing.medium,
                children: cards,
              ),
          ],
        ),
      ],
    );
  }
}

/// Ikonice režima, kao na platnu (Izgled).
const _modeGlyph = {
  AppThemeMode.light: TavliIcons.lightMode,
  AppThemeMode.dark: TavliIcons.darkMode,
  AppThemeMode.system: TavliIcons.systemMode,
};

/// Kartica teme: naziv i mali primer (red recepta i glavno dugme) u bojama
/// te teme, u trenutnom režimu.
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
    final brightness = Theme.of(context).brightness;
    final preview = buildTavliTheme(theme.motif, brightness);
    final p = TavliPalette.of(theme.motif, brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: theme.label,
      onTap: onTap,
      excludeSemantics: true,
      child: TavliCard(
        selected: selected,
        onTap: onTap,
        child: Theme(
          data: preview,
          // Primer je samo slika teme: dodir bira celu karticu.
          child: IgnorePointer(
            child: ColoredBox(
              color: p.bg,
              child: Padding(
                padding: const EdgeInsets.all(TavliSpacing.small),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: TavliSpacing.medium,
                  children: [
                    TavliSectionHeader(
                      theme.label,
                      style: TavliSectionHeaderStyle.bold,
                      trailing: selected
                          ? TavliIcon(TavliIcons.check, color: p.primary)
                          : null,
                    ),
                    const TavliListGroup(
                      children: [
                        TavliListRow(
                          title: 'Pasta sa povrćem',
                          subtitle: 'Recept · 20 min',
                          leading: TavliThumbnail.row(
                            glyph: TavliIcons.recipes,
                          ),
                        ),
                      ],
                    ),
                    TavliButton.primary(
                      label: 'Otvori recept',
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
