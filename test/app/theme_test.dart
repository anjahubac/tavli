import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/app/theme/app_theme.dart';
import 'package:tavli/app/theme/tavli_colors.dart';
import 'package:tavli/app/theme/tavli_palette.dart';
import 'package:tavli/app/theme/tavli_status_colors.dart';
import 'package:tavli/domain/theme_choice.dart';

void main() {
  for (final theme in TavliTheme.values) {
    for (final brightness in Brightness.values) {
      test('${theme.label} ${brightness.name}: tokeni u ThemeData', () {
        final p = TavliPalette.of(theme, brightness);
        final t = buildTavliTheme(theme, brightness);
        final c = t.colorScheme;

        expect(t.useMaterial3, isTrue);
        expect(t.brightness, brightness);
        expect(c.primary, p.primary);
        expect(c.onPrimary, p.onPrimary);
        expect(c.primaryContainer, p.container);
        expect(c.onPrimaryContainer, p.onContainer);
        expect(c.surface, p.surface);
        expect(c.onSurface, p.text);
        expect(c.onSurfaceVariant, p.muted);
        expect(c.outlineVariant, p.line);
        expect(c.outline, p.boxLine);
        expect(t.scaffoldBackgroundColor, p.bg);

        final x = t.extension<TavliColors>()!;
        expect(x.motif, theme);
        expect(x.tints, p.tints);
        expect(x.line, p.line);

        expect(t.textTheme.headlineSmall?.fontFamily, tavliFontFamily);
        expect(t.textTheme.headlineSmall?.fontWeight, FontWeight.w700);
        expect(t.textTheme.headlineSmall?.letterSpacing, lessThan(0));
        expect(t.cardTheme.elevation, 0);
        expect(t.navigationBarTheme.indicatorColor, p.container);
      });
    }
  }

  double contrast(Color a, Color b) {
    final one = a.computeLuminance(), two = b.computeLuminance();
    return ((one > two ? one : two) + 0.05) / ((one < two ? one : two) + 0.05);
  }

  test('svih šest paleta ima čitljiv tekst, dugmad i okvire', () {
    for (final theme in TavliTheme.values) {
      for (final brightness in Brightness.values) {
        final p = TavliPalette.of(theme, brightness);
        for (final bg in [p.surface, p.bg]) {
          expect(contrast(p.text, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(p.muted, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(p.boxLine, bg), greaterThanOrEqualTo(3));
        }
        expect(contrast(p.primary, p.onPrimary), greaterThanOrEqualTo(4.5));
        expect(contrast(p.onContainer, p.container), greaterThanOrEqualTo(4.5));
        final t = buildTavliTheme(theme, brightness);
        expect(t.textTheme.bodyMedium?.fontSize, 16);
        expect(t.textTheme.bodyMedium?.height, 1.5);
        {
          final c = t.colorScheme;
          final levels = [
            c.surfaceContainerLowest,
            c.surfaceContainerLow,
            c.surfaceContainer,
            c.surfaceContainerHigh,
            c.surfaceContainerHighest,
          ];
          for (var i = 1; i < levels.length; i++) {
            expect(
              levels[i].computeLuminance(),
              brightness == Brightness.dark
                  ? greaterThan(levels[i - 1].computeLuminance())
                  : lessThan(levels[i - 1].computeLuminance()),
            );
          }
        }
      }
    }
  });

  test('statusi imaju iste čitljive boje u svim paletama', () {
    for (final brightness in Brightness.values) {
      final expected = brightness == Brightness.light
          ? TavliStatusColors.light
          : TavliStatusColors.dark;
      for (final theme in TavliTheme.values) {
        final status = buildTavliTheme(
          theme,
          brightness,
        ).extension<TavliStatusColors>()!;
        expect(status.success, expected.success);
        expect(status.warning, expected.warning);
        expect(status.info, expected.info);
        for (final tone in [status.success, status.warning, status.info]) {
          expect(
            contrast(tone.foreground, tone.background),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    }
  });

  test('palete se razlikuju po temi i osvetljenosti', () {
    final primaries = {
      for (final theme in TavliTheme.values)
        for (final b in Brightness.values) TavliPalette.of(theme, b).primary,
    };
    expect(primaries, hasLength(6));
  });

  testWidgets('svih 6 tema se iscrtava bez grešaka', (tester) async {
    for (final theme in TavliTheme.values) {
      for (final b in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTavliTheme(theme, b),
            home: Scaffold(
              appBar: AppBar(title: const Text('Recepti')),
              body: const Column(
                children: [
                  Card(child: Text('Sarma')),
                  Chip(label: Text('Ručak')),
                  FilterChip(
                    label: Text('Sve'),
                    selected: true,
                    onSelected: null,
                  ),
                  SearchBar(hintText: 'Pretraži recepte'),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: 'A'),
                  NavigationDestination(icon: Icon(Icons.list), label: 'B'),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
