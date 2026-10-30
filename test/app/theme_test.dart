import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/app/theme/app_theme.dart';
import 'package:tavli/app/theme/tavli_colors.dart';
import 'package:tavli/app/theme/tavli_palette.dart';
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
        expect(t.textTheme.headlineSmall?.fontWeight, FontWeight.w800);
        expect(t.textTheme.headlineSmall?.letterSpacing, lessThan(0));
        expect(t.cardTheme.elevation, 0);
        expect(t.navigationBarTheme.indicatorColor, p.container);
      });
    }
  }

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
