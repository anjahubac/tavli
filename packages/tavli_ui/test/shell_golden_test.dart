@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/src/gallery/shell_sections.dart';
import 'package:tavli_ui/tavli_ui.dart';

/// Slike kostura ekrana: telefon (Android) i računar (macOS) u 3 teme,
/// svetlo i tamno, plus iOS i Windows u Bosiljku. Kao i ostale slike,
/// prave se i porede samo na Linuxu (`scripts/update-goldens.sh`).
final _skip = Platform.isLinux
    ? null
    : 'slike izgleda se proveravaju samo na Linuxu (CI)';

TargetPlatform _target(TavliPlatform p) => switch (p) {
  TavliPlatform.android => TargetPlatform.android,
  TavliPlatform.ios => TargetPlatform.iOS,
  TavliPlatform.macos => TargetPlatform.macOS,
  TavliPlatform.windows => TargetPlatform.windows,
};

void main() {
  final cases = [
    for (final motif in TavliMotif.values)
      for (final brightness in Brightness.values)
        for (final platform in const [
          TavliPlatform.android,
          TavliPlatform.macos,
        ])
          (motif, brightness, platform),
    for (final brightness in Brightness.values)
      for (final platform in const [TavliPlatform.ios, TavliPlatform.windows])
        (TavliMotif.bosiljak, brightness, platform),
  ];
  for (final (motif, brightness, platform) in cases) {
    final name = '${platform.name}_${motif.name}_${brightness.name}';
    testWidgets('kostur: $name', skip: _skip != null, (tester) async {
      final width = platform.isDesktop ? 900.0 : 400.0;
      tester.view.physicalSize = Size(width, 2800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final theme = buildTavliTheme(
        motif,
        brightness,
      ).copyWith(platform: _target(platform));
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ColoredBox(
                key: const ValueKey('golden'),
                color: theme.scaffoldBackgroundColor,
                child: const Padding(
                  padding: EdgeInsets.all(TavliSpacing.large),
                  child: TavliShellGallerySections(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile('goldens/shell_$name.png'),
      );
    });
  }
}
