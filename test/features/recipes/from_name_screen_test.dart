import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    await tester.enterText(
      find.widgetWithText(TextField, 'Naziv jela'),
      'sarma',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Više porcija'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Želje (nije obavezno)'),
      'bez luka',
    );
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
    expect(find.widgetWithText(AppBar, 'Sarma'), findsOneWidget);
  });

  testTavli('odbacivanje ne čuva ništa', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/name',
      ai: [aiAnswer(recipeJson('Sarma'))],
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Naziv jela'),
      'sarma',
    );
    await tester.pump();
    await tapButton(tester, 'Napravi recept');

    await tapButton(tester, 'Odbaci');

    expect(await app.titles(), isEmpty);
    expect(find.widgetWithText(TextField, 'Naziv jela'), findsOneWidget);
    expect(find.text('sarma'), findsOneWidget);
  });

  testTavli('greška AI-ja daje poruku na srpskom i čuva unos', (tester) async {
    await pumpTavli(
      tester,
      location: '/recipes/new/name',
      ai: [(401, '{"error":"bad key"}', {})],
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Naziv jela'),
      'sarma',
    );
    await tester.pump();
    await tapButton(tester, 'Napravi recept');

    expect(
      find.text('Nijedan model nije dostupan. Proveri ključeve.'),
      findsOneWidget,
    );
    expect(button('Pokušaj ponovo'), findsOneWidget);
    expect(find.text('sarma'), findsOneWidget);
  });

  testTavli('na širokom ekranu sačuvan recept je izabran u listi', (
    tester,
  ) async {
    await pumpTavli(
      tester,
      size: wide,
      location: '/recipes/new/name',
      ai: [aiAnswer(recipeJson('Musaka'))],
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Naziv jela'),
      'musaka',
    );
    await tester.pump();
    await tapButton(tester, 'Napravi recept');
    await tapButton(tester, 'Sačuvaj');

    expect(find.byType(SearchBar), findsOneWidget);
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Musaka')).selected,
      isTrue,
    );
  });
}
