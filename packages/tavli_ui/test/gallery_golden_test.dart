@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/src/gallery/tavli_gallery.dart';
import 'package:tavli_ui/tavli_ui.dart';

/// Testovi izgleda (slike) prave se i porede samo na Linuxu, kao u CI-ju,
/// jer se tekst iscrtava malo drugačije na svakom sistemu.
/// Nove slike: `scripts/update-goldens.sh` (Linux kontejner).
final _skip = Platform.isLinux
    ? null
    : 'slike izgleda se proveravaju samo na Linuxu (CI)';

void main() {
  for (final motif in TavliMotif.values) {
    for (final brightness in Brightness.values) {
      final name = '${motif.name}_${brightness.name}';
      testWidgets('galerija: $name', skip: _skip != null, (tester) async {
        tester.view.physicalSize = const Size(400, 1600);
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
            home: Scaffold(
              body: SingleChildScrollView(
                child: ColoredBox(
                  key: const ValueKey('golden'),
                  color: theme.scaffoldBackgroundColor,
                  child: const Padding(
                    padding: EdgeInsets.all(TavliSpacing.large),
                    child: TavliFoundationGallerySections(),
                  ),
                ),
              ),
            ),
          ),
        );
        await expectLater(
          find.byKey(const ValueKey('golden')),
          matchesGoldenFile('goldens/gallery_$name.png'),
        );
      });
    }
  }
}
