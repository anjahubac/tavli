import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/test_app.dart';

void main() {
  /// Bela kartica ekrana prijave na računaru.
  Finder panel() => find.ancestor(
    of: find.text('Kako da te zovemo?'),
    matching: find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).borderRadius != null,
    ),
  );

  // Ista pravila na svakom računaru: kartica je u sredini prostora koji
  // aplikacija crta. Na macOS-u to je ceo prozor (traka sa semaforima je
  // providna), a na Windows-u deo ispod sistemske naslovne trake.
  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.android,
  ]) {
    testTavli('široko: kartica u sredini prozora (${platform.name})', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await pumpTavli(tester, name: null, size: wide);
      expect(tester.takeException(), isNull);
      final card = tester.getRect(panel().first);
      expect(card.center.dy, moreOrLessEquals(wide.height / 2, epsilon: 1));
      expect(card.center.dx, moreOrLessEquals(wide.width / 2, epsilon: 1));
    });
  }
}
