import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/domain/cookbook.dart';
import 'package:tavli/features/cookbooks/cookbook_providers.dart';
import 'package:tavli/features/recipes/recipe_providers.dart';

import '../../helpers/fake_cookbooks.dart';
import '../../helpers/test_app.dart';

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
    await tester.tap(
      find.widgetWithText(ActionChip, 'Kada počinje Božićni post?'),
    );
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
    expect(find.byType(CloseButton), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(CloseButton), findsNothing);
    expect(find.text('Post i praznici'), findsOneWidget);
  });
}
