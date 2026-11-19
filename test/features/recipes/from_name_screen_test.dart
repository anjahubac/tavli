import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/test_app.dart';

void main() {
  testTavli('po nazivu jela: pregled pa čuvanje otvara recept', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/name',
      ai: [aiAnswer(recipeJson('Sarma', servings: 3))],
    );
    expect(
      tester.widget<ButtonStyleButton>(button('Napravi recept')).enabled,
      isFalse,
    );

    await tester.enterText(textField('Naziv jela'), 'sarma');
    await tester.pump();
    await tester.tap(find.byTooltip('Više porcija'));
    await tester.enterText(textField('Želje (nije obavezno)'), 'bez luka');
    await tapButton(tester, 'Napravi recept');

    final prompt = app.adapter.requests.single.data.toString();
    expect(prompt, contains('sarma'));
    expect(prompt, contains('Servings: 3'));
    expect(prompt, contains('bez luka'));
    expect(find.text('Sarma'), findsOneWidget);
    expect(find.text('• 0,5 kg crni luk'), findsOneWidget);
    expect(find.text('Napravio: Gemini Pro'), findsOneWidget);
    expect(await app.titles(), isEmpty);

    await tapButton(tester, 'Sačuvaj');

    expect(await app.titles(), ['Sarma']);
    expect(find.text('Recept je sačuvan.'), findsOneWidget);
    expect(recipeHeading('Sarma'), findsOneWidget);
  });

  testTavli('AI oznake se vide u pregledu i čuvaju sa receptom', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/name',
      ai: [
        aiAnswer({
          ...recipeJson('Pasulj'),
          'meals': ['lunch', 'dinner'],
          'weight': 'hearty',
          'dishKind': 'cooked',
        }),
      ],
    );
    await tester.enterText(textField('Naziv jela'), 'pasulj');
    await tester.pump();
    await tapButton(tester, 'Napravi recept');

    expect(find.text('Oznake'), findsOneWidget);
    expect(find.text('Izmeni oznake'), findsNothing, reason: 'samo pregled');
    await tapButton(tester, 'Sačuvaj');

    final row = await app.db.select(app.db.recipes).getSingle();
    expect(row.mealTypesJson, '["lunch","dinner"]');
    expect(row.weight, 'hearty');
    expect(row.dishKind, 'cooked');
    expect(row.labelsSource, 'ai');
  });

  testTavli('odbacivanje ne čuva ništa', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/name',
      ai: [aiAnswer(recipeJson('Sarma'))],
    );
    await tester.enterText(textField('Naziv jela'), 'sarma');
    await tester.pump();
    await tapButton(tester, 'Napravi recept');

    await tapButton(tester, 'Odbaci');

    expect(await app.titles(), isEmpty);
    expect(textField('Naziv jela'), findsOneWidget);
    expect(find.text('sarma'), findsOneWidget);
  });

  testTavli('greška AI-ja daje poruku na srpskom i čuva unos', (tester) async {
    await pumpTavli(
      tester,
      location: '/recipes/new/name',
      ai: [(401, '{"error":"bad key"}', {})],
    );
    await tester.enterText(textField('Naziv jela'), 'sarma');
    await tester.pump();
    await tapButton(tester, 'Napravi recept');

    expect(
      find.text('Nijedan model nije dostupan. Proveri ključeve.'),
      findsOneWidget,
    );
    expect(button('Pokušaj ponovo'), findsOneWidget);
    expect(find.text('sarma'), findsOneWidget);
  });

  testTavli('na širokom ekranu sačuvan recept se otvara kao ceo ekran', (
    tester,
  ) async {
    await pumpTavli(
      tester,
      size: wide,
      location: '/recipes/new/name',
      ai: [aiAnswer(recipeJson('Musaka'))],
    );
    await tester.enterText(textField('Naziv jela'), 'musaka');
    await tester.pump();
    await tapButton(tester, 'Napravi recept');
    await tapButton(tester, 'Sačuvaj');

    // Platno nema listu i detalj u Receptima: recept je ceo ekran.
    expect(recipeHeading('Musaka'), findsOneWidget);
    expect(find.byType(TavliSearchField), findsNothing);
  });

  testTavli('320 px, tekst 2×: brojač porcija prelazi ispod natpisa', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpTavli(
      tester,
      size: const Size(320, 900),
      location: '/recipes/new/name',
    );
    final label = tester.getRect(find.text('Broj porcija'));
    final plus = tester.getRect(find.byTooltip('Više porcija'));
    expect(plus.top, greaterThanOrEqualTo(label.bottom));
    await tester.tap(find.byTooltip('Više porcija'));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
