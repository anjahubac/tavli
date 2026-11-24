import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/meal_plan_repository.dart';
import 'package:tavli/data/shopping_repository.dart';
import 'package:tavli/domain/meal_plan.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/shopping_source.dart';
import 'package:tavli/features/planning/planning_providers.dart';
import 'package:tavli/features/recipes/recipe_providers.dart';
import 'package:tavli/features/shopping/shopping_list_view.dart';
import 'package:tavli/features/shopping/shopping_providers.dart';
import 'package:tavli/providers.dart';
import 'package:tavli/sync/synced_writer.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/test_app.dart';

/// Sreda u prvoj nedelji plana 2–15. novembra.
final today = DateTime(2026, 11, 4, 9);

final twoWeeks = DateRange(CivilDate(2026, 11, 2), CivilDate(2026, 11, 15));

Future<AccountScope> scopeOf(AppDatabase db) async {
  final account = await db.select(db.accounts).getSingle();
  return AccountScope(userId: account.userId, householdId: account.householdId);
}

/// Ručak svaki dan: 1 kg krompira i so bez količine.
Future<String> seedPlan(
  AppDatabase db,
  DateRange range, {
  Ingredient? salt,
}) async {
  final scope = await scopeOf(db);
  final writer = SyncedWriter(db, accountId: scope.userId);
  final repo = MealPlanRepository(
    db,
    scope: scope,
    writer: writer,
    shopping: ShoppingRepository(db, scope: scope, writer: writer),
    clock: () => DateTime.utc(2026, 11),
  );
  final request = PlanRequest(range: range, mealTypes: const {MealType.lunch});
  String key(MealSlot s) => 'ručak ${s.date.month}-${s.date.day}';
  return repo.approve(
    PlanDraft(
      request: request,
      proposals: {
        for (final s in request.slots)
          s: SlotProposal(
            title: 'Ručak ${s.date.day}.${s.date.month}.',
            draftRecipeKey: key(s),
          ),
      },
      newRecipes: {
        for (final s in request.slots)
          key(s): RecipeSnapshot(
            title: 'Ručak ${s.date.day}.${s.date.month}.',
            baseServings: 2,
            ingredients: [
              const Ingredient(
                name: 'krompir',
                quantity: 1,
                unit: 'kg',
                category: 'voće i povrće',
              ),
              salt ?? const Ingredient(name: 'so', category: 'začini i sosovi'),
            ],
          ),
      },
    ),
  );
}

/// Bez plana: samo nabavka po receptu (dve stavke).
Future<void> seedRecipeOnly(AppDatabase db) async {
  final scope = await scopeOf(db);
  await ShoppingRepository(
    db,
    scope: scope,
    writer: SyncedWriter(db, accountId: scope.userId),
  ).addRecipePreparation(
    snapshot: const RecipeSnapshot(
      title: 'Musaka',
      baseServings: 4,
      ingredients: [
        Ingredient(name: 'patlidžan', quantity: 2, unit: 'kom'),
        Ingredient(name: 'mleko', quantity: 0.5, unit: 'l'),
      ],
    ),
    servings: 4,
    originKey: 'recipe:musaka',
  );
}

Future<TestApp> pumpShopping(
  WidgetTester tester, {
  Size size = phone,
  String location = '/shopping',
  Future<void> Function(AppDatabase db)? setup,
}) => pumpTavli(
  tester,
  size: size,
  location: location,
  setup: setup ?? (db) => seedPlan(db, twoWeeks),
  overrides: [clockProvider.overrideWithValue(() => today)],
);

Finder tileOf(String name) => find
    .ancestor(of: find.text(name), matching: find.byType(TavliCheckRow))
    .first;

/// Dugme samo sa ikonicom iz biblioteke, po opisu.
Finder iconButton(String label) => find.byWidgetPredicate(
  (w) => w is TavliIconButton && w.semanticLabel == label,
);

Future<void> tapIn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('oznaka približne količine se prikazuje samo kada je zadata', () {
    expect(amountLabel(35, 'ml', approximate: true), '~35 ml');
    expect(amountLabel(35, 'ml'), '35 ml');
    expect(amountLabel(null, 'ml', approximate: true), isNull);
  });

  for (final failPlans in [true, false]) {
    testTavli('greška ${failPlans ? 'planova' : 'nabavke'} nije prazno stanje; '
        'ponovni pokušaj učitava podatke', (tester) async {
      var attempts = 0;
      await pumpTavli(
        tester,
        location: '/shopping',
        overrides: [
          mealPlansProvider.overrideWith((ref) {
            if (failPlans && attempts++ == 0) {
              return Stream.error(StateError('synthetic failure'));
            }
            return Stream.value([]);
          }),
          recipeShoppingProvider.overrideWith((ref) {
            if (!failPlans && attempts++ == 0) {
              return Stream.error(StateError('synthetic failure'));
            }
            return Stream.value([]);
          }),
        ],
      );
      expect(
        find.text('Nabavka trenutno ne može da se prikaže.'),
        findsOneWidget,
      );
      expect(find.text('Još nemaš plan'), findsNothing);
      expect(find.text('Nabavka je prazna'), findsNothing);
      await tapButton(tester, 'Pokušaj ponovo');
      expect(find.text('Nabavka je prazna'), findsOneWidget);
    });
  }

  testTavli('početni izbor čeka oba učitavanja', (tester) async {
    final plans = StreamController<List<MealPlan>>();
    final items = StreamController<List<ShoppingItemRow>>();
    addTearDown(plans.close);
    addTearDown(items.close);
    await pumpTavli(
      tester,
      location: '/shopping',
      settle: false,
      overrides: [
        mealPlansProvider.overrideWith((ref) => plans.stream),
        recipeShoppingProvider.overrideWith((ref) => items.stream),
      ],
    );
    plans.add([]);
    await tester.pump();
    expect(find.text('Još nemaš plan'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    items.add([]);
    await tester.pumpAndSettle();
    expect(find.text('Nabavka je prazna'), findsOneWidget);
  });

  for (final failPlanItems in [true, false]) {
    testTavli(
      'greška ${failPlanItems ? 'stavki plana' : 'priprema'} ima retry',
      (tester) async {
        var attempts = 0;
        await pumpTavli(
          tester,
          location: '/shopping',
          setup: failPlanItems
              ? (db) => seedPlan(db, twoWeeks)
              : seedRecipeOnly,
          overrides: [
            if (failPlanItems)
              planShoppingProvider.overrideWith((ref, planId) {
                if (attempts++ == 0) {
                  return Stream.error(StateError('synthetic failure'));
                }
                return ref
                    .watch(shoppingRepositoryProvider)
                    .watchPlanItems(planId);
              })
            else
              preparationsProvider.overrideWith((ref) {
                if (attempts++ == 0) {
                  return Stream.error(StateError('synthetic failure'));
                }
                return ref
                    .watch(shoppingRepositoryProvider)
                    .watchPreparations();
              }),
          ],
        );
        expect(
          find.text('Nabavka trenutno ne može da se prikaže.'),
          findsOneWidget,
        );
        expect(find.textContaining('synthetic failure'), findsNothing);
        await tapButton(tester, 'Pokušaj ponovo');
        expect(
          find.text(failPlanItems ? 'krompir' : 'patlidžan'),
          findsOneWidget,
        );
      },
    );
  }

  testTavli('početni prikaz ostaje isti kada stigne novi plan', (tester) async {
    final app = await pumpShopping(tester, setup: seedRecipeOnly);
    expect(find.text('Recepti u nabavci'), findsOneWidget);
    await seedPlan(app.db, twoWeeks);
    await tester.pumpAndSettle();
    expect(find.text('Recepti u nabavci'), findsOneWidget);
    await tapIn(tester, find.text('Po planu'));
    expect(find.text('krompir'), findsOneWidget);
  });

  testTavli('greška izabranog prikaza po receptu može ponovo da se učita', (
    tester,
  ) async {
    final updates = StreamController<List<ShoppingItemRow>>.broadcast();
    addTearDown(updates.close);
    var rows = <ShoppingItemRow>[];
    await pumpTavli(
      tester,
      location: '/shopping',
      setup: (db) async {
        await seedRecipeOnly(db);
        rows = await db.select(db.shoppingItems).get();
      },
      overrides: [
        recipeShoppingProvider.overrideWith((ref) async* {
          yield rows;
          yield* updates.stream;
        }),
      ],
    );
    expect(find.text('patlidžan'), findsOneWidget);
    updates.addError(StateError('synthetic failure'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nabavka trenutno ne može da se prikaže.'),
      findsOneWidget,
    );
    await tapButton(tester, 'Pokušaj ponovo');
    expect(find.text('patlidžan'), findsOneWidget);
  });

  testTavli('iz plana u dva dodira: nabavka tekuće nedelje po kategorijama', (
    tester,
  ) async {
    await pumpShopping(tester, location: '/plan');
    await tapIn(tester, find.text('Otvori nabavku'));

    expect(find.text('Po planu'), findsOneWidget);
    expect(find.text('Po receptu'), findsOneWidget);
    expect(find.text('2–8. novembar 2026.'), findsOneWidget);
    expect(find.text('VOĆE I POVRĆE'), findsOneWidget);
    expect(find.text('ZAČINI I SOSOVI'), findsOneWidget);
    expect(find.text('krompir'), findsOneWidget);
    expect(find.text('7 kg'), findsOneWidget);
    // Nepoznata količina se ne izmišlja.
    expect(find.text('Proveri količinu'), findsOneWidget);
  });

  for (final planned in [true, false]) {
    final mode = planned ? 'Po planu' : 'Po receptu';
    testTavli('$mode prikazuje prstohvat soli sa oznakom za proveru', (
      tester,
    ) async {
      const salt = Ingredient(
        name: 'so',
        quantity: 1,
        unit: 'prstohvata',
        category: 'začini i sosovi',
      );
      final app = await pumpShopping(
        tester,
        size: planned ? wide : phone,
        setup: (db) async {
          if (planned) {
            await seedPlan(db, twoWeeks, salt: salt);
            return;
          }
          final scope = await scopeOf(db);
          await ShoppingRepository(
            db,
            scope: scope,
            writer: SyncedWriter(db, accountId: scope.userId),
          ).addRecipePreparation(
            snapshot: const RecipeSnapshot(
              title: 'Supa',
              baseServings: 2,
              ingredients: [
                salt,
                Ingredient(name: 'so', quantity: 5, unit: 'g'),
              ],
            ),
            servings: 2,
            originKey: 'recipe:supa',
          );
        },
      );

      void expectReview(String amount) {
        final pinchRow = find.widgetWithText(TavliCheckRow, amount);
        expect(
          find.descendant(
            of: pinchRow,
            matching: find.text('Proveri količinu'),
          ),
          findsOneWidget,
        );
      }

      expectReview(planned ? '7 prstohvat' : '1 prstohvat');
      expect(find.text(planned ? '7 kg' : '5 g'), findsOneWidget);
      if (planned) {
        await tapIn(tester, find.text('Ceo plan'));
        expectReview('14 prstohvat');
        expect(find.text('14 kg'), findsOneWidget);
      }
      final pinches = (await app.db.select(app.db.shoppingItems).get()).where(
        (item) => item.unit == 'prstohvat',
      );
      expect(pinches.map((item) => item.quantity), planned ? [7, 7] : [1]);
    });
  }

  testTavli('kašike ostaju u originalnoj meri u nedelji i celom planu', (
    tester,
  ) async {
    await pumpShopping(
      tester,
      setup: (db) => seedPlan(
        db,
        twoWeeks,
        salt: const Ingredient(
          name: 'so',
          quantity: 1,
          unit: 'kašike',
          category: 'začini i sosovi',
        ),
      ),
    );

    expect(find.text('7 kašika'), findsOneWidget);
    await tapIn(tester, find.text('Ceo plan'));
    expect(find.text('14 kašika'), findsOneWidget);
  });

  testTavli('stavka pokazuje za koje obroke je', (tester) async {
    await pumpShopping(tester);
    expect(find.byTooltip('Za koje obroke'), findsNothing);
    final semantics = tester.widget<Semantics>(
      find
          .descendant(
            of: tileOf('krompir'),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Semantics && w.properties.customSemanticsActions != null,
            ),
          )
          .first,
    );
    expect(
      semantics.properties.customSemanticsActions!.keys.single.label,
      'Za koje obroke',
    );
    await tester.longPress(tileOf('krompir'));
    await tester.pumpAndSettle();
    expect(find.text('ZA KOJE OBROKE'), findsOneWidget);
    expect(find.text('Ručak 2.11.'), findsOneWidget);
    expect(
      find.text('Ponedeljak, 2. novembar · Ručak · 2 porcije'),
      findsOneWidget,
    );
    expect(find.text('Ručak 9.11.'), findsNothing);
  });

  testTavli('širok ekran: lista i detalj „Za koje obroke“', (tester) async {
    await pumpShopping(tester, size: wide);
    expect(find.text('Nabavka'), findsWidgets);
    // Kao na platnu: prva stavka je izabrana i detalj je desno.
    expect(find.text('ZA KOJE OBROKE'), findsOneWidget);
    expect(find.text('7 kg ukupno'), findsOneWidget);
    expect(
      find.text('Ponedeljak, 2. novembar · Ručak · 2 porcije'),
      findsOneWidget,
    );

    // Dodir na red bira stavku; štiklira se samo polje.
    await tapIn(tester, find.text('so'));
    expect(find.text('Kupljeno · 1'), findsNothing);
    expect(find.text('7 kg ukupno'), findsNothing);
    expect(find.text('ZA KOJE OBROKE'), findsOneWidget);
  });

  testTavli('štikliranje odmah prebacuje u Kupljeno, Poništi vraća; prijem '
      'u ostavu zaključava kupovinu', (tester) async {
    await pumpShopping(tester);
    await tapIn(tester, tileOf('krompir'));

    expect(find.text('Kupljeno: krompir'), findsOneWidget);
    expect(find.text('Kupljeno · 1'), findsOneWidget);
    await tester.tap(find.text('Poništi'));
    await tester.pumpAndSettle();
    expect(find.text('Kupljeno · 1'), findsNothing);
    expect(find.text('7 kg'), findsOneWidget);

    await tapIn(tester, tileOf('krompir'));
    await tapIn(tester, find.text('Prebaci u ostavu (1)'));
    expect(find.text('Prebačeno u ostavu: 1'), findsOneWidget);
    expect(find.text('7 kg · U ostavi'), findsOneWidget);
    expect(find.textContaining('Prebaci u ostavu'), findsNothing);
    expect(tester.widget<TavliCheckRow>(tileOf('krompir')).onChanged, isNull);
  });

  testTavli('ručna stavka: brzo dodavanje i brisanje', (tester) async {
    await pumpShopping(tester);
    await tester.enterText(find.byType(TextField), 'Deterdžent');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('OSTALO'), findsOneWidget);
    expect(find.text('Deterdžent'), findsOneWidget);

    await tapIn(
      tester,
      find.descendant(of: tileOf('Deterdžent'), matching: iconButton('Obriši')),
    );
    expect(find.text('Deterdžent'), findsNothing);
    expect(find.text('Obrisano: Deterdžent'), findsOneWidget);
  });

  for (final accessible in [false, true]) {
    testTavli('Poništi i Vrati: pristupačna navigacija $accessible', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(accessibleNavigation: accessible);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpShopping(tester);
      await tapIn(tester, tileOf('krompir'));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Poništi'), accessible ? findsOneWidget : findsNothing);
      if (accessible) {
        await tester.tap(find.text('Poništi'));
        await tester.pumpAndSettle();
        expect(find.text('Kupljeno · 1'), findsNothing);
      }

      await tester.enterText(find.byType(TextField), 'Deterdžent');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tapIn(
        tester,
        find.descendant(
          of: tileOf('Deterdžent'),
          matching: iconButton('Obriši'),
        ),
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Vrati'), accessible ? findsOneWidget : findsNothing);
      if (accessible) {
        await tester.tap(find.text('Vrati'));
        await tester.pumpAndSettle();
        expect(find.text('Deterdžent'), findsOneWidget);
      }
    });
  }

  testTavli('ceo plan sabira nedelje; kupovina u njemu se vidi u nedelji', (
    tester,
  ) async {
    await pumpShopping(tester);
    expect(find.text('Nedelja 1'), findsOneWidget);
    expect(find.text('Nedelja 2'), findsOneWidget);

    await tapIn(tester, find.text('Ceo plan'));
    expect(
      find.text('2–15. novembar 2026. · zbir svih nedelja'),
      findsOneWidget,
    );
    expect(find.text('14 kg'), findsOneWidget);
    await tapIn(tester, tileOf('krompir'));
    expect(find.text('Kupljeno · 1'), findsOneWidget);
    expect(find.text('kupljeno 14 kg'), findsOneWidget);

    await tapIn(tester, find.text('Nedelja 2'));
    expect(find.text('9–15. novembar 2026.'), findsOneWidget);
    expect(find.text('Kupljeno · 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('7 kg'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('krompir'), findsOneWidget);
  });

  testTavli('bez plana i bez stavki: prazna nabavka; po receptu radi bez '
      'plana', (tester) async {
    await pumpShopping(tester, setup: (_) async {});
    expect(find.text('Nabavka je prazna'), findsOneWidget);
    expect(find.text('Napravi plan'), findsOneWidget);
  });

  testTavli('bez plana, sa nabavkom po receptu: „Po planu“ kaže šta čeka i '
      'nema drugog dugmeta', (tester) async {
    await pumpShopping(tester, setup: seedRecipeOnly);
    await tapIn(tester, find.text('Po planu'));
    expect(find.text('Još nemaš plan'), findsOneWidget);
    expect(
      find.text('U „Po receptu“ te čeka 2 stavke za kupovinu.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Napravi plan'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    await tapIn(tester, find.text('Po receptu'));
    expect(find.text('Recepti u nabavci'), findsOneWidget);
    expect(find.text('patlidžan'), findsOneWidget);
  });

  for (final size in [const Size(320, 700), const Size(400, 800), wide]) {
    testTavli('${size.width} px, tekst 2×: „Po planu“ bez plana bez '
        'preliva', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpShopping(tester, size: size, setup: seedRecipeOnly);
      await tapIn(tester, find.text('Po planu'));
      expect(find.text('Napravi plan'), findsOneWidget);
      for (final text in ['Po planu', 'Po receptu']) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        final paintedWidth =
            (paragraph.localToGlobal(Offset(paragraph.size.width, 0)) -
                    paragraph.localToGlobal(Offset.zero))
                .distance;
        expect(
          paintedWidth,
          closeTo(paragraph.size.width, 0.01),
          reason: 'Tekst 2× se ne smanjuje: $text',
        );
        expect(paragraph.textScaler.scale(16), 32);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 700), wide]) {
    testTavli(
      '${size.width} px: tamna tema, tekst 2×, bez animacija, tastatura',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await pumpTavli(
          tester,
          size: size,
          location: '/shopping',
          setup: seedRecipeOnly,
          settings: {'theme_mode': 'dark'},
        );
        expect(
          Theme.of(tester.element(find.text('Po planu'))).brightness,
          Brightness.dark,
        );
        Focus.of(tester.element(find.text('Po planu'))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(find.text('Još nemaš plan'), findsOneWidget);
        Focus.of(tester.element(find.text('Po receptu'))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(find.text('Recepti u nabavci'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testTavli('po receptu bez plana: pripreme i njihove stavke; uklanjanje '
      'pripreme čuva kupljeno', (tester) async {
    await pumpShopping(
      tester,
      setup: (db) async {
        final scope = await scopeOf(db);
        final shop = ShoppingRepository(
          db,
          scope: scope,
          writer: SyncedWriter(db, accountId: scope.userId),
        );
        await shop.addRecipePreparation(
          snapshot: const RecipeSnapshot(
            title: 'Musaka',
            baseServings: 4,
            ingredients: [
              Ingredient(
                name: 'patlidžan',
                quantity: 2,
                unit: 'kom',
                category: 'voće i povrće',
              ),
              Ingredient(name: 'mleko', quantity: 0.5, unit: 'l'),
            ],
          ),
          servings: 4,
          originKey: 'recipe:musaka',
        );
      },
    );
    // Bez plana, a sa nabavkom po receptu: odmah se otvara „Po receptu“.
    expect(find.text('Još nemaš plan'), findsNothing);
    expect(find.text('Recepti u nabavci'), findsOneWidget);
    expect(find.text('4 porcije · 2 sastojka za kupovinu'), findsOneWidget);
    await tapIn(tester, tileOf('patlidžan'));
    await tester.ensureVisible(tileOf('mleko'));
    await tester.longPress(tileOf('mleko'));
    await tester.pumpAndSettle();
    expect(find.text('Recept · 4 porcije'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tapIn(tester, iconButton('Ukloni iz nabavke'));
    expect(find.text('Recepti u nabavci'), findsNothing);
    expect(find.text('mleko'), findsNothing);
    expect(find.text('patlidžan'), findsOneWidget);
    expect(find.text('Kupljeno · 1'), findsOneWidget);
  });

  // Prijavljeno na macOS-u (trekped): posle „Po receptu“ nije moglo nazad
  // na „Po planu“. Klik trekpedom na macOS-u stiže kao miš.
  for (final size in [phone, wide]) {
    for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
      testTavli('prekidač „Po planu“ / „Po receptu“ deset puta tamo i nazad '
          '(${kind.name}, ${size.width} px)', (tester) async {
        await pumpShopping(tester, size: size);
        for (var i = 0; i < 10; i++) {
          await tester.tap(find.text('Po receptu'), kind: kind);
          await tester.pumpAndSettle();
          expect(find.text('Ceo plan'), findsNothing, reason: 'po receptu $i');
          await tester.tap(find.text('Po planu'), kind: kind);
          await tester.pumpAndSettle();
          expect(find.text('Ceo plan'), findsOneWidget, reason: 'po planu $i');
        }
      });
    }
  }

  for (final size in [const Size(320, 700), wide]) {
    testTavli('${size.width} px, tekst 2×: bez preliva', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpShopping(tester, size: size);
      await tapIn(tester, find.text('Ceo plan'));
      await tapIn(tester, find.text('Po receptu'));
      expect(tester.takeException(), isNull);
    });
  }
}
