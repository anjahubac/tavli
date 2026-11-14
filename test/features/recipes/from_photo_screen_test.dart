import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/ai/ai_models.dart';

import '../../helpers/test_app.dart';

void main() {
  testTavli('slika → pregled → čuvanje čuva i sliku', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/photo',
      ai: [aiAnswer(recipeJson('Bakina pita'))],
    );
    app.picker.next = fakePhoto;

    await tapButton(tester, 'Izaberi iz galerije');

    expect(app.picker.calls, [false]);
    final body = app.adapter.requests.single.data.toString();
    expect(body, contains(AIImage(fakePhoto).toDataUrl()));
    expect(find.text('Bakina pita'), findsOneWidget);
    expect(app.photos.saved, isEmpty);

    await tapButton(tester, 'Sačuvaj');

    expect(await app.titles(), ['Bakina pita']);
    final path = app.photos.saved.keys.single;
    final row = await app.db.select(app.db.recipes).getSingle();
    expect(row.imagePath, path);
    expect(row.source, 'photo');
    expect(find.widgetWithText(AppBar, 'Bakina pita'), findsOneWidget);
  });

  testTavli('slikanje kamerom kad postoji kamera', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/photo',
      ai: [aiAnswer(recipeJson('Pita'))],
    );
    app.picker.next = fakePhoto;

    await tapButton(tester, 'Slikaj');
    expect(app.picker.calls, [true]);
  });

  testTavli('bez kamere nudi se samo galerija', (tester) async {
    await pumpTavli(
      tester,
      location: '/recipes/new/photo',
      canUseCamera: false,
    );
    expect(find.text('Slikaj'), findsNothing);
    expect(find.text('Izaberi iz galerije'), findsOneWidget);
  });

  testTavli('slika bez recepta: poruka i izbor druge slike', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/photo',
      ai: [
        aiAnswer({'error': 'not_a_recipe'}),
      ],
    );
    app.picker.next = fakePhoto;

    await tapButton(tester, 'Izaberi iz galerije');

    expect(find.text('Na slici nije pronađen recept.'), findsOneWidget);
    expect(find.text('Pokušaj ponovo'), findsNothing);
    await tapButton(tester, 'Izaberi drugu sliku');
    expect(find.text('Izaberi iz galerije'), findsOneWidget);
    expect(await app.titles(), isEmpty);
  });

  testTavli('odustajanje od izbora ne menja ništa', (tester) async {
    final app = await pumpTavli(tester, location: '/recipes/new/photo');

    await tapButton(tester, 'Izaberi iz galerije');

    expect(app.adapter.requests, isEmpty);
    expect(find.text('Izaberi iz galerije'), findsOneWidget);
  });

  testTavli('odbačen pregled ne ostavlja sliku', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/photo',
      ai: [aiAnswer(recipeJson('Pita'))],
    );
    app.picker.next = fakePhoto;
    await tapButton(tester, 'Izaberi iz galerije');

    await tapButton(tester, 'Odbaci');

    expect(app.photos.saved, isEmpty);
    expect(await app.titles(), isEmpty);
  });

  testTavli('spor AI: Prekini zaustavlja čekanje, slika ostaje', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/recipes/new/photo',
      ai: [aiAnswer(recipeJson('Pita'))],
    );
    app.picker.next = fakePhoto;
    final gate = app.adapter.gate = Completer<void>();

    await tester.tap(button('Izaberi iz galerije'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Čitam recept sa slike…'), findsOneWidget);

    await tester.tap(button('Prekini'));
    await tester.pump();
    expect(find.text('Čitanje je prekinuto.'), findsOneWidget);
    expect(button('Pokušaj ponovo'), findsOneWidget);

    // Kasni odgovor se ne prikazuje.
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Pita'), findsNothing);
    expect(find.text('Čitanje je prekinuto.'), findsOneWidget);
  });
}
