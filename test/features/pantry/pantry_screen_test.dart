import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/features/pantry/pantry_screen.dart';
import 'package:tavli/sync/catalog_status.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/test_app.dart';

/// Namirnice u ostavi prijavljenog domaćinstva (naziv, količina, jedinica).
Future<void> Function(AppDatabase) pantry(
  List<(String, double?, String?)> items,
) => (db) async {
  final account = await db.select(db.accounts).getSingle();
  for (final (i, (name, quantity, unit)) in items.indexed) {
    await db
        .into(db.pantryItems)
        .insert(
          PantryItemsCompanion.insert(
            id: 'p$i',
            name: name,
            quantity: Value(quantity),
            unit: Value(unit),
            category: 'ostalo',
            addedAt: DateTime.utc(2026, 11, 20),
            householdId: Value(account.householdId),
          ),
        );
  }
};

const _items = [
  ('Mleko', 1.0, 'l'),
  ('Brašno', null, null),
  ('Jaja', 6.0, 'kom'),
];

Finder _message(String text) => find.descendant(
  of: find.byType(TavliMessageBar),
  matching: find.text(text),
);

/// „Ukloni“ koje otkriva prevlačenje reda sa datim nazivom.
Finder _removeIn(String name) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(TavliListRow)),
  matching: find.text('Ukloni'),
);

/// Kanta u redu tabele (oblačić iz material_ui ne vidi `find.byTooltip`).
final _trash = find.byWidgetPredicate(
  (w) => w is Tooltip && w.message == 'Ukloni iz ostave',
);

void main() {
  test('broj namirnica po padežu', () {
    expect(pantryCountLabel(1), '1 namirnica');
    expect(pantryCountLabel(3), '3 namirnice');
    expect(pantryCountLabel(7), '7 namirnica');
    expect(pantryCountLabel(12), '12 namirnica');
    expect(pantryCountLabel(21), '21 namirnica');
    expect(pantryCountLabel(23), '23 namirnice');
  });

  testTavli('prazna ostava: animacija i poruka, bez pretrage', (tester) async {
    await pumpTavli(tester, location: '/pantry');
    expect(find.text('Još nema unetih namirnica'), findsOneWidget);
    expect(find.byType(TavliSearchField), findsNothing);
  });

  testTavli('telefon: lista po nazivu, količina samo kad je poznata', (
    tester,
  ) async {
    await pumpTavli(tester, location: '/pantry', setup: pantry(_items));
    expect(find.text('3 namirnice'), findsOneWidget);
    final rows = tester
        .widgetList<TavliListRow>(find.byType(TavliListRow))
        .toList();
    expect([for (final r in rows) r.title], ['Brašno', 'Jaja', 'Mleko']);
    expect([for (final r in rows) r.quantity], [null, '6 kom', '1 l']);
    // Bez oznake „imam“: prisustvo u ostavi je dovoljno.
    expect(find.textContaining('Imam'), findsNothing);
    expect(find.text('Dodaj namirnicu'), findsOneWidget);
  });

  testTavli('pretraga sužava listu, a broj ostaje ukupan', (tester) async {
    await pumpTavli(tester, location: '/pantry', setup: pantry(_items));
    await tester.enterText(find.byType(TextField), 'mle');
    await tester.pumpAndSettle();
    expect(find.byType(TavliListRow), findsOneWidget);
    expect(find.text('Mleko'), findsOneWidget);
    expect(find.text('3 namirnice'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sir');
    await tester.pumpAndSettle();
    expect(find.text('Nema namirnica za „sir“.'), findsOneWidget);
  });

  testTavli('prevlačenje ulevo i „Ukloni“; „Vrati“ ga vraća', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/pantry',
      setup: pantry(_items),
    );
    await tester.drag(find.text('Jaja'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(_removeIn('Jaja'));
    await tester.pumpAndSettle();
    expect(find.text('Jaja'), findsNothing);
    expect(find.text('2 namirnice'), findsOneWidget);
    expect(_message('Uklonjeno: Jaja'), findsOneWidget);

    await tester.tap(find.text('Vrati'));
    await tester.pumpAndSettle();
    expect(find.text('Jaja'), findsOneWidget);
    expect(await app.db.select(app.db.pantryItems).get(), hasLength(3));
  });

  testTavli('posle poruke bez „Vrati“ namirnica je obrisana i ide na server', (
    tester,
  ) async {
    final app = await pumpTavli(
      tester,
      location: '/pantry',
      setup: pantry(_items),
    );
    await tester.drag(find.text('Mleko'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(_removeIn('Mleko'));
    await tester.pumpAndSettle();
    await tester.pump(tavliMessageDuration);
    await tester.pumpAndSettle();

    final names = [
      for (final r in await app.db.select(app.db.pantryItems).get()) r.name,
    ];
    expect(names, unorderedEquals(['Brašno', 'Jaja']));
    final deletes =
        await (app.db.select(app.db.syncOutbox)..where(
              (t) => t.entity.equals('pantry_item') & t.op.equals('delete'),
            ))
            .get();
    expect([for (final d in deletes) d.recordId], ['p0']);
    expect(find.text('Mleko'), findsNothing);
  });

  testTavli('računar: zaglavlje, tabela i kanta kad je miš iznad reda', (
    tester,
  ) async {
    await pumpTavli(
      tester,
      size: wide,
      location: '/pantry',
      setup: pantry(_items),
    );
    expect(find.byType(TavliPageHeader), findsOneWidget);
    expect(find.text('Namirnica'), findsOneWidget);
    expect(find.text('Količina'), findsOneWidget);
    expect(find.byType(TavliFloatingButton), findsNothing);
    expect(_trash, findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Jaja')));
    await tester.pumpAndSettle();
    expect(_trash, findsOneWidget);

    await tester.tap(_trash);
    await tester.pumpAndSettle();
    expect(find.text('Jaja'), findsNothing);
    expect(_message('Uklonjeno: Jaja'), findsOneWidget);
  });

  testTavli('tekst 2× na uskom telefonu: bez prelivanja', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpTavli(
      tester,
      size: const Size(320, 640),
      location: '/pantry',
      setup: pantry([
        ('Maslinovo ulje ekstra devičansko', 0.75, 'l'),
        ..._items,
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('4 namirnice'), findsOneWidget);
  });

  group('dodavanje namirnice', () {
    Future<void> seeded(AppDatabase db) async {
      await pantry(_items)(db);
      final account = await db.select(db.accounts).getSingle();
      await (db.update(
        db.accounts,
      )..where((t) => t.userId.equals(account.userId))).write(
        AccountsCompanion(catalogStatus: Value(CatalogStatus.available.name)),
      );
      final t = DateTime.utc(2026, 11);
      for (final (id, name, unit) in [
        ('f1', 'Pavlaka', 'milliliter'),
        ('f2', 'Paprika', 'piece'),
      ]) {
        await db
            .into(db.foods)
            .insert(
              FoodsCompanion.insert(
                id: id,
                slug: id,
                name: name,
                category: 'mlečni proizvodi i jaja',
                baseUnit: unit,
                createdAt: t,
                updatedAt: t,
              ),
            );
      }
    }

    testTavli('pretraga kataloga, količina i jedinica, pa red u ostavi', (
      tester,
    ) async {
      final app = await pumpTavli(tester, location: '/pantry', setup: seeded);
      await tester.tap(find.text('Dodaj namirnicu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'pap');
      await tester.pumpAndSettle();
      expect(find.text('Paprika'), findsOneWidget);
      expect(find.text('Pavlaka'), findsNothing);
      await tester.tap(find.text('Paprika'));
      await tester.pumpAndSettle();

      // Količina nije obavezna; jedinica je predložena iz kataloga (kom).
      await tester.tap(iconButton('Više'));
      await tester.tap(iconButton('Više'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dodaj u ostavu'));
      await tester.pumpAndSettle();

      final row = (await app.db.select(app.db.pantryItems).get()).firstWhere(
        (r) => r.name == 'Paprika',
      );
      expect(
        [row.quantity, row.unit, row.category],
        [2, 'kom', 'mlečni proizvodi i jaja'],
      );
      expect(find.text('Paprika'), findsOneWidget);
      expect(find.text('2 kom'), findsOneWidget);
    });

    testTavli(
      'namirnica koje nema u katalogu dodaje se kao nova, bez količine',
      (tester) async {
        final app = await pumpTavli(tester, location: '/pantry', setup: seeded);
        await tester.tap(find.text('Dodaj namirnicu'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Kari');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dodaj „Kari“ kao novu namirnicu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dodaj u ostavu'));
        await tester.pumpAndSettle();

        final row = (await app.db.select(app.db.pantryItems).get()).firstWhere(
          (r) => r.name == 'Kari',
        );
        expect([row.quantity, row.unit, row.category], [null, null, 'ostalo']);
        expect(find.text('4 namirnice'), findsOneWidget);
      },
    );

    testTavli('namirnica koja je već u ostavi to piše i dodaje količinu', (
      tester,
    ) async {
      final app = await pumpTavli(tester, location: '/pantry', setup: seeded);
      await tester.tap(find.text('Dodaj namirnicu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Mleko');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dodaj „Mleko“ kao novu namirnicu'));
      await tester.pumpAndSettle();
      expect(find.text('Već u ostavi: 1 l'), findsOneWidget);
      await tester.tap(iconButton('Više'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('l'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dodaj u ostavu'));
      await tester.pumpAndSettle();

      final milk = (await app.db.select(app.db.pantryItems).get()).where(
        (r) => r.name == 'Mleko',
      );
      expect(milk.single.quantity, 2);
      expect(find.text('3 namirnice'), findsOneWidget);
    });
  });

  testTavli('dodir na red otvara izmenu količine i čuva je', (tester) async {
    final app = await pumpTavli(
      tester,
      location: '/pantry',
      setup: pantry(_items),
    );
    await tester.tap(find.text('Jaja'));
    await tester.pumpAndSettle();
    expect(find.text('Količina (nije obavezna)'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Više'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Sačuvaj');
    final rows = await app.db.select(app.db.pantryItems).get();
    final eggs = rows.singleWhere((r) => r.name == 'Jaja');
    expect([eggs.quantity, eggs.unit], [7, 'kom']);
    expect(find.text('Količina (nije obavezna)'), findsNothing);
  });

  testTavli('„Slikaj namirnice“ u dodavanju vodi na ekran slike', (
    tester,
  ) async {
    await pumpTavli(tester, location: '/pantry', setup: pantry(_items));
    await tester.tap(find.text('Dodaj namirnicu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slikaj namirnice'));
    await tester.pumpAndSettle();
    expect(find.text('Namirnice sa slike'), findsOneWidget);
  });
}
