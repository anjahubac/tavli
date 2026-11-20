@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/src/gallery/content_sections.dart';
import 'package:tavli_ui/tavli_ui.dart';

/// Slike kartica, lista, napomena i stanja u 3 teme, svetlo i tamno, plus Bosiljak sa
/// tekstom 2x. Kao i ostale slike, prave se i porede samo na Linuxu
/// (`scripts/update-goldens.sh`).
final _skip = Platform.isLinux
    ? null
    : 'slike izgleda se proveravaju samo na Linuxu (CI)';

void main() {
  final cases = [
    for (final motif in TavliMotif.values)
      for (final brightness in Brightness.values) (motif, brightness, 1.0),
    (TavliMotif.bosiljak, Brightness.light, 2.0),
  ];
  for (final (motif, brightness, scale) in cases) {
    final name =
        '${motif.name}_${brightness.name}${scale == 1 ? '' : '_text2x'}';
    testWidgets('sadržaj: $name', skip: _skip != null, (tester) async {
      tester.view.physicalSize = const Size(400, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final theme = buildTavliTheme(
        motif,
        brightness,
      ).copyWith(platform: TargetPlatform.android);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: scale,
            maxScaleFactor: scale,
            child: Scaffold(
              body: SingleChildScrollView(
                child: ColoredBox(
                  key: const ValueKey('golden'),
                  color: theme.scaffoldBackgroundColor,
                  child: const Padding(
                    padding: EdgeInsets.all(TavliSpacing.large),
                    child: TavliContentGallerySections(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile('goldens/content_$name.png'),
      );
    });
  }
}
