import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/data/database.dart';

import '../../helpers/test_app.dart';

Map<String, dynamic> _photo() => {
  'items': [
    {
      'name': 'mleko',
      'quantity': 1,
      'unit': 'l',
      'category': 'mlečni proizvodi i jaja',
    },
    {'name': 'hleb', 'quantity': null, 'unit': null, 'category': 'ostalo'},
  ],
};

Future<List<String>> _names(AppDatabase db) async =>
    [for (final r in await db.select(db.pantryItems).get()) r.name]..sort();

void main() {
  testTavli('slika: pregled, uklanjanje stavke i dodavanje u ostavu', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/pantry/photo',
      ai: [aiAnswer(_photo())],
    );
    expect(find.text('Namirnice sa slike'), findsOneWidget);

    app.picker.next = fakePhoto;
    await tapButton(tester, 'Izaberi iz galerije');
    expect(find.text('mleko'), findsOneWidget);
    expect(find.text('hleb'), findsOneWidget);
    expect(find.text('Dodaj u ostavu (2)'), findsOneWidget);

    await tester.tap(find.text('hleb'));
    await tester.pumpAndSettle();
    expect(find.text('Dodaj u ostavu (1)'), findsOneWidget);

    await tapButton(tester, 'Dodaj u ostavu (1)');
    expect(await _names(app.db), ['mleko']);
    expect(find.text('Dodato u ostavu: 1'), findsOneWidget);
  });

  testTavli('slika: odustajanje i odbacivanje ne dodaju ništa', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/pantry/photo',
      ai: [aiAnswer(_photo())],
    );
    await tapButton(tester, 'Izaberi iz galerije');
    expect(app.adapter.requests, isEmpty);

    app.picker.next = fakePhoto;
    await tapButton(tester, 'Izaberi iz galerije');
    await tapButton(tester, 'Odbaci');
    expect(find.text('Izaberi iz galerije'), findsOneWidget);
    expect(await _names(app.db), isEmpty);
  });

  testTavli('slika bez namirnica prikazuje poruku', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/pantry/photo',
      ai: [
        aiAnswer({'error': 'no_food'}),
      ],
    );
    app.picker.next = fakePhoto;
    await tapButton(tester, 'Izaberi iz galerije');
    expect(find.text('Na slici nisu prepoznate namirnice.'), findsOneWidget);
    expect(await _names(app.db), isEmpty);
  });

  testTavli('pregled slike staje na 320 širine sa dvostrukim tekstom', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final app = await pumpTavli(
      tester,
      size: const Size(320, 800),
      location: '/pantry/photo',
      ai: [aiAnswer(_photo())],
    );
    app.picker.next = fakePhoto;
    await tapButton(tester, 'Izaberi iz galerije');
    expect(app.picker.calls, [false]);
    expect(find.text('Dodaj u ostavu (2)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
