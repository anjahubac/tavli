import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/domain/cookbook.dart';
import 'package:tavli/features/cookbooks/cookbook_providers.dart';
import 'package:tavli/features/recipes/recipe_providers.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/fake_cookbooks.dart';
import '../../helpers/test_app.dart';

final closePanel = find.byWidgetPredicate(
  (w) => w is TavliIconButton && w.semanticLabel == 'Zatvori panel',
);

void main() {
  testTavli('Početna → kalendar → odgovor iz dva izvora', (tester) async {
    final repo = FakeCookbookRepository()
      ..answer = const CookbookAnswer(
        content: 'Probaj čorbu od sočiva.',
        sources: [
          CookbookSource(bookId: '', recipeId: 'soup', title: 'Čorba', page: 0),
          CookbookSource(bookId: 'book', title: 'Knorr', page: 12),
        ],
      );
    await pumpTavli(
      tester,
      location: '/home',
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 23)),
        cookbookRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.ensureVisible(find.text('Post i praznici'));
    await tester.tap(find.text('Post i praznici'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kada počinje Božićni post?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('28. novembra 2026.'), findsOneWidget);
    expect(find.text('Izvor: Crkveni kalendar SPC'), findsOneWidget);
    expect(repo.questions, isEmpty);

    await tester.enterText(find.byType(TextField), 'Posni pasulj');
    await tester.tap(find.byTooltip('Pošalji pitanje'));
    await tester.pumpAndSettle();
    expect(repo.includedRecipes, isTrue);
    expect(find.text('Sačuvani recept: Čorba'), findsOneWidget);
    expect(find.text('Izvor: Knorr, str. 12'), findsOneWidget);
    final plan = find.text('Napravi posni plan');
    await tester.ensureVisible(plan);
    await tester.tap(plan);
    await tester.pumpAndSettle();
    expect(find.text('Novi posni plan'), findsOneWidget);
  });

  testTavli('na računaru se otvara panel i može da se zatvori', (tester) async {
    await pumpTavli(tester, location: '/home', size: const Size(1200, 760));
    await tester.tap(find.text('Post i praznici'));
    await tester.pumpAndSettle();
    final close = closePanel;
    expect(close, findsOneWidget);
    // Panel se odvaja od Početne levom ivicom i senkom (dizajn MacPostPanel).
    final edge = find.ancestor(
      of: closePanel,
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            ((w.decoration as BoxDecoration).border as Border?)?.left.width ==
                1 &&
            (w.decoration as BoxDecoration).boxShadow?.single.offset ==
                const Offset(-8, 0),
      ),
    );
    expect(edge, findsOneWidget);
    // Kanvas MacPostPanel: širina 400, naslov levo, X desno.
    final panel = tester.getRect(edge);
    expect(panel.width, 400);
    expect(panel.right, 1200);
    expect(
      tester.getCenter(close).dx,
      greaterThan(tester.getCenter(find.text('Post i praznici').last).dx),
    );
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(closePanel, findsNothing);
    expect(find.text('Post i praznici'), findsOneWidget);
  });

  for (final (name, size) in const [
    ('panel', Size(1200, 760)),
    ('telefon', Size(390, 844)),
  ]) {
    testTavli('$name staje sa dvostrukim tekstom', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTavli(tester, location: '/home', size: size);
      final card = find.text('Post i praznici');
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final chip = find.text('Da li je sutra posno?');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ODGOVOR'), findsOneWidget);
    });
  }
}
