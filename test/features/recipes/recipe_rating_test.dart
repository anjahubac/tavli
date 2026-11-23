import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/test_app.dart';

Future<void> _summary(TestApp app, String recipeId, double avg, int n) => app.db
    .into(app.db.ratingSummaries)
    .insert(
      RatingSummariesCompanion.insert(
        householdId: app.scope.householdId,
        recipeId: recipeId,
        averageStars: avg,
        ratingCount: n,
      ),
    );

Finder _filled(TavliIconData icon) =>
    find.byWidgetPredicate((w) => w is TavliIcon && w.icon == icon && w.filled);

void main() {
  testTavli('detalj bez ocena ne pokazuje prosek, a nudi Oceni', (
    tester,
  ) async {
    await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Pasulj')],
    );
    expect(find.text('Oceni'), findsOneWidget);
    expect(find.text('Omiljeni'), findsOneWidget);
    expect(find.byType(TavliIcon), findsWidgets);
    expect(_filled(TavliIcons.star), findsNothing);
  });

  testTavli('detalj pokazuje prosek i broj ocena', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Pasulj')],
    );
    await _summary(app, 'a', 4.333, 3);
    await tester.pumpAndSettle();
    expect(find.textContaining('4,3'), findsOneWidget);
    expect(find.textContaining('3 ocene'), findsOneWidget);
  });

  testTavli('panel pokazuje kratku napomenu o privatnosti', (tester) async {
    await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Pasulj')],
    );
    await tester.tap(find.text('Oceni'));
    await tester.pumpAndSettle();
    expect(find.text('Da li ti se svidelo?'), findsOneWidget);
    expect(
      find.text('Vidiš samo ti. Ukućani vide samo prosek.'),
      findsOneWidget,
    );
  });

  testTavli('sačuvana ocena menja dugme, prikazuje belešku, pa se menja', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Pasulj')],
    );

    await tester.tap(find.text('Oceni'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('4 od 5'));
    await tester.enterText(find.byType(EditableText), 'Manje soli');
    await tester.pump();
    await tapButton(tester, 'Sačuvaj');

    expect(find.text('Ocena je sačuvana.'), findsOneWidget);
    expect(find.text('Tvoja ocena: 4'), findsOneWidget);
    expect(find.text('Manje soli'), findsOneWidget);
    final rows = await app.db.select(app.db.ratings).get();
    expect(rows.single.stars, 4);
    expect(rows.single.comment, 'Manje soli');

    // Nova vrednost sa praznom beleškom menja isti red i briše belešku.
    await tester.ensureVisible(find.text('Tvoja ocena: 4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tvoja ocena: 4'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('2 od 5'));
    await tester.enterText(find.byType(EditableText), '');
    await tester.pump();
    await tapButton(tester, 'Sačuvaj');

    expect(find.text('Tvoja ocena: 2'), findsOneWidget);
    expect(find.text('Manje soli'), findsNothing);
    final updated = await app.db.select(app.db.ratings).get();
    expect(updated, hasLength(1));
    expect(updated.single.stars, 2);
    expect(updated.single.comment, isNull);
  });

  testTavli('Otkaži zatvara panel bez čuvanja', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Pasulj')],
    );
    await tester.tap(find.text('Oceni'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('5 od 5'));
    await tapButton(tester, 'Otkaži');
    expect(find.text('Da li ti se svidelo?'), findsNothing);
    expect(await app.db.select(app.db.ratings).get(), isEmpty);
  });

  testTavli('srce čuva i skida omiljeni recept', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Pasulj')],
    );
    expect(_filled(TavliIcons.like), findsNothing);
    await tester.tap(find.text('Omiljeni'));
    await tester.pumpAndSettle();
    expect(_filled(TavliIcons.like), findsOneWidget);
    expect(await app.db.select(app.db.userFavorites).get(), hasLength(1));

    await tester.tap(find.text('Omiljeni'));
    await tester.pumpAndSettle();
    expect(_filled(TavliIcons.like), findsNothing);
  });

  testTavli('lista pokazuje prosek samo ocenjenim receptima', (tester) async {
    final app = await pumpTavli(
      tester,
      recipes: [sampleRecipe('a', 'Pasulj'), sampleRecipe('b', 'Sarma')],
    );
    await _summary(app, 'a', 4.333, 3);
    await tester.pumpAndSettle();
    expect(find.textContaining('4,3 (3)'), findsOneWidget);
    expect(_filled(TavliIcons.star), findsOneWidget);
  });

  testTavli('širok ekran: panel je najviše 480 širok', (tester) async {
    await pumpTavli(
      tester,
      size: const Size(1200, 900),
      location: '/recipes/a',
      recipes: [sampleRecipe('a', 'Pasulj')],
    );
    await tester.tap(find.text('Oceni'));
    await tester.pumpAndSettle();
    final panel = tester.getSize(
      find
          .ancestor(
            of: find.text('Da li ti se svidelo?'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(panel.width, lessThanOrEqualTo(480));
  });
}
