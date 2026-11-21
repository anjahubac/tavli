import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/data/database.dart';
import 'package:tavli/data/meal_plan_repository.dart';
import 'package:tavli/data/shopping_repository.dart';
import 'package:tavli/domain/meal_plan.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/shopping_source.dart';
import 'package:tavli/features/planning/plan_calendar.dart';
import 'package:tavli/features/planning/planning_providers.dart';
import 'package:tavli/features/recipes/recipe_providers.dart';
import 'package:tavli/sync/synced_writer.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/test_app.dart';

/// Sreda usred plana 2–8. novembra.
final today = DateTime(2026, 11, 4, 9);

String location(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri
        .toString();

/// Sačuvan plan ručkova: `Ručak <dan>.<mesec>.` za svaki dan [range].
Future<String> seedPlan(
  AppDatabase db,
  DateRange range, {
  DateTime? createdAt,
}) async {
  final account = await db.select(db.accounts).getSingle();
  final scope = AccountScope(
    userId: account.userId,
    householdId: account.householdId,
  );
  final writer = SyncedWriter(db, accountId: scope.userId);
  final repo = MealPlanRepository(
    db,
    scope: scope,
    writer: writer,
    shopping: ShoppingRepository(db, scope: scope, writer: writer),
    clock: () => createdAt ?? DateTime.utc(2026, 11),
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
            prepMinutes: 40,
            ingredients: const [
              Ingredient(name: 'krompir', quantity: 1, unit: 'kg'),
            ],
          ),
      },
    ),
  );
}

final week = DateRange(CivilDate(2026, 11, 2), CivilDate(2026, 11, 8));

Future<TestApp> pumpPlan(
  WidgetTester tester, {
  Size size = phone,
  Future<void> Function(AppDatabase db)? setup,
  List<(int, String, Map<String, List<String>>)> ai = const [],
  List<Recipe> recipes = const [],
}) => pumpTavli(
  tester,
  size: size,
  location: '/plan',
  ai: ai,
  recipes: recipes,
  setup: setup ?? (db) => seedPlan(db, week),
  overrides: [clockProvider.overrideWithValue(() => today)],
);

/// Skroluje listu plana dok se tekst ne pojavi (lista se gradi lenjo).
Future<void> show(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    // Od vrha liste naniže.
    await tester.drag(find.byType(ListView).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
  }
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  expect(finder, findsWidgets);
}

/// Povratak sa ekrana obroka na Plan (širok ekran: „Plan“ iznad naslova).
Future<void> backToPlan(WidgetTester tester) async {
  await tester.tap(
    find
        .descendant(
          of: find.byType(TavliPageHeader),
          matching: find.text('Plan'),
        )
        .hitTestable()
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await show(tester, text);
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kalendar meseca: dan sa pet obroka ima pet oznaka', (
    tester,
  ) async {
    final day = CivilDate(2026, 11, 3);
    final plan = MealPlan(
      id: 'p1',
      range: week,
      mealTypes: MealType.values.toSet(),
      defaultServings: 2,
      usePantry: false,
      createdAt: DateTime.utc(2026, 11),
    );
    final meals = [
      for (final t in MealType.values)
        PlannedMeal(
          id: t.name,
          planId: 'p1',
          slot: MealSlot(day, t),
          servings: 2,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTavliTheme(TavliMotif.bosiljak, Brightness.light),
        home: Scaffold(
          body: PlanMonthCalendar(
            plan: plan,
            meals: meals,
            selected: CivilDate(2026, 11, 2),
            today: CivilDate(2026, 11, 2),
            onSelect: (_) {},
          ),
        ),
      ),
    );

    final dots = find.descendant(
      of: find
          .ancestor(of: find.text('3'), matching: find.byType(Column))
          .first,
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(dots, findsNWidgets(5));
  });
  testTavli('telefon: traka dana sa izabranim danom i njegovim obrocima; '
      'obrok otvara recept iz plana', (tester) async {
    await pumpPlan(tester);

    expect(find.text('Otvori nabavku'), findsOneWidget);
    expect(find.text('Ponovo predloži'), findsOneWidget);
    expect(find.text('2. – 8. novembar'), findsOneWidget);
    await show(tester, 'Sreda, 4. novembar');
    expect(find.text('Ručak 4.11.'), findsOneWidget);
    expect(find.text('Ručak 2.11.'), findsNothing);
    expect(find.text('Napravi plan'), findsNothing);

    await tester.tap(find.bySemanticsLabel(RegExp('^Ponedeljak, 2. novembar')));
    await tester.pumpAndSettle();
    expect(find.text('Ponedeljak, 2. novembar'), findsOneWidget);
    expect(find.text('Ručak 2.11.'), findsOneWidget);
    await tapText(tester, 'Danas');

    await tapText(tester, 'Ručak 4.11.');

    expect(location(tester), startsWith('/plan/'));
    expect(location(tester), contains('/entries/'));
    expect(find.text('Sastojci za 2 porcije · 40 min'), findsOneWidget);
    expect(find.text('• 1 kg krompir'), findsOneWidget);
    expect(find.text('Zameni jelo'), findsOneWidget);
  });

  testTavli('mesec: kompaktan kalendar, izbor dana pokazuje njegove '
      'obroke; Danas vraća na danas', (tester) async {
    await pumpPlan(
      tester,
      setup: (db) => seedPlan(
        db,
        DateRange(CivilDate(2026, 11, 1), CivilDate(2026, 11, 30)),
      ),
    );

    await tapText(tester, 'Mesec');
    expect(
      find.bySemanticsLabel(RegExp('Sreda, 4. novembar, 1 obrok, danas')),
      findsOneWidget,
    );

    expect(find.text('Novembar 2026'), findsOneWidget);
    expect(find.text('skuvano'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Utorak, 17. novembar')));
    await tester.pumpAndSettle();
    await show(tester, 'Ručak 17.11.');
    expect(find.text('Ručak 4.11.'), findsNothing);

    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tapText(tester, 'Danas');
    await show(tester, 'Ručak 4.11.');
  });

  testTavli('nedelja: strelice idu kroz nedelje plana', (tester) async {
    await pumpPlan(
      tester,
      setup: (db) => seedPlan(
        db,
        DateRange(CivilDate(2026, 11, 1), CivilDate(2026, 11, 30)),
      ),
    );

    expect(find.text('2. – 8. novembar'), findsOneWidget);
    await tester.tap(iconButton('Sledeća nedelja'));
    await tester.pumpAndSettle();
    expect(find.text('9. – 15. novembar'), findsOneWidget);
    await show(tester, 'Sreda, 11. novembar');
    await tester.tap(iconButton('Prethodna nedelja'));
    await tester.pumpAndSettle();
    await tester.tap(iconButton('Prethodna nedelja'));
    await tester.pumpAndSettle();
    // Plan počinje u nedelju 1. novembra: dani pre toga se ne biraju.
    expect(find.text('26. oktobar – 1. novembar'), findsOneWidget);
    await show(tester, 'Nedelja, 1. novembar');
    final previous = tester.widget<TavliIconButton>(
      iconButton('Prethodna nedelja'),
    );
    expect(previous.onPressed, isNull);
  });

  testTavli('više planova: podrazumevan je onaj sa današnjim danom; drugi '
      'se bira', (tester) async {
    await pumpPlan(
      tester,
      setup: (db) async {
        await seedPlan(db, week, createdAt: DateTime.utc(2026, 10));
        await seedPlan(
          db,
          DateRange(CivilDate(2026, 12, 7), CivilDate(2026, 12, 13)),
          createdAt: DateTime.utc(2026, 11, 3),
        );
      },
    );

    await show(tester, 'Ručak 4.11.');
    await tapText(tester, '2–8. novembar 2026.');
    expect(find.text('Izaberi plan'), findsOneWidget);
    await tester.tap(find.text('7–13. decembar 2026.').last);
    await tester.pumpAndSettle();

    await show(tester, 'Ručak 7.12.');
    expect(find.text('Ručak 4.11.'), findsNothing);
  });

  testTavli('320 px i dvostruk tekst: nedelja, mesec i obrok bez '
      'odsečenog sadržaja', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPlan(tester, size: const Size(320, 700));

    expect(find.text('Otvori nabavku'), findsOneWidget);
    await tapText(tester, 'Mesec');
    expect(tester.takeException(), isNull);
    await tapText(tester, 'Ručak 4.11.');
    expect(find.text('Zameni jelo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testTavli('promena širine čuva izabrani dan; telefon čuva i skrol', (
    tester,
  ) async {
    final month = DateRange(CivilDate(2026, 11, 1), CivilDate(2026, 11, 30));
    await pumpPlan(
      tester,
      size: const Size(400, 560),
      setup: (db) => seedPlan(db, month),
    );
    await tapText(tester, 'Mesec');
    await tester.tap(find.bySemanticsLabel(RegExp('^Sreda, 18. novembar')));
    await tester.pumpAndSettle();
    final list = find.byType(ListView).first;
    final container = ProviderScope.containerOf(tester.element(list));
    expect(container.read(planViewProvider).date, CivilDate(2026, 11, 18));
    final scrollable = find
        .descendant(of: list, matching: find.byType(Scrollable))
        .first;
    await tester.drag(scrollable, const Offset(0, -150));
    await tester.pumpAndSettle();
    final offset = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(offset, greaterThan(0));

    for (final width in [560.0, 719.0]) {
      tester.view.physicalSize = Size(width, 560);
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        closeTo(offset, 1),
        reason: 'width: $width',
      );
    }
    for (final width in [720.0, 1200.0, 719.0]) {
      tester.view.physicalSize = Size(width, 560);
      await tester.pumpAndSettle();
      expect(location(tester), '/plan');
      expect(container.read(planViewProvider).date, CivilDate(2026, 11, 18));
      expect(tester.takeException(), isNull, reason: 'width: $width');
    }
  });

  testTavli('široko: nedelja je mreža sedam dana; obrok se otvara na svom '
      'ekranu sa povratkom na Plan', (tester) async {
    await pumpPlan(tester, size: wide);

    expect(find.text('Plan'), findsWidgets);
    for (var d = 2; d <= 8; d++) {
      expect(find.text('Ručak $d.11.'), findsOneWidget);
    }
    await tapText(tester, 'Mesec');
    expect(find.text('PON'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Petak, 6. novembar')));
    await tester.pumpAndSettle();
    expect(find.text('Ručak 2.11.'), findsOneWidget);

    await tapText(tester, 'Ručak 4.11.');
    expect(location(tester), contains('/entries/'));
    expect(find.text('Sastojci za 2 porcije · 40 min'), findsOneWidget);
    await backToPlan(tester);
    expect(location(tester), '/plan');
  });

  testTavli('zaključan obrok: oznaka u kalendaru, zamena i uklanjanje '
      'nisu dostupni', (tester) async {
    await pumpPlan(tester, size: wide);
    await tapText(tester, 'Ručak 4.11.');

    await tapText(tester, 'Zaključaj');

    expect(find.text('Zaključano'), findsWidgets);
    expect(find.text('Otključaj'), findsOneWidget);
    final replace = tester.widget<ButtonStyleButton>(button('Zameni jelo'));
    expect(replace.onPressed, isNull);
    await backToPlan(tester);
    expect(find.text('Ručak 4.11.'), findsOneWidget);
  });

  testTavli('skuvano iz Plana ide kroz zajedničko mesto: zapis kuvanja, '
      'pa poništavanje', (tester) async {
    final app = await pumpPlan(tester, size: wide);
    await tapText(tester, 'Ručak 4.11.');

    await tapText(tester, 'Označi kao skuvano');

    expect(find.text('Nije skuvano'), findsOneWidget);
    final events = await app.db.select(app.db.cookedEvents).get();
    expect(events, hasLength(1));
    expect(events.single.undoneAt, isNull);

    await tapText(tester, 'Nije skuvano');

    expect(find.text('Označi kao skuvano'), findsOneWidget);
    final undone = await app.db.select(app.db.cookedEvents).getSingle();
    expect(undone.id, events.single.id);
    expect(undone.undoneAt, isNotNull);
  });

  testTavli('porcije obroka se menjaju i sastojci se preračunavaju', (
    tester,
  ) async {
    await pumpPlan(tester, size: wide);
    await tapText(tester, 'Ručak 4.11.');

    await tester.tap(iconButton('Više porcija').last);
    await tester.pumpAndSettle();

    expect(find.text('Sastojci za 3 porcije · 40 min'), findsOneWidget);
    expect(find.text('• 1,5 kg krompir'), findsOneWidget);
  });

  testTavli('zamena receptom iz biblioteke: pregled pa prihvatanje', (
    tester,
  ) async {
    await pumpPlan(
      tester,
      size: wide,
      recipes: [sampleRecipe('lib-1', 'Sarma')],
    );
    await tapText(tester, 'Ručak 4.11.');

    await tapText(tester, 'Zameni jelo');
    await tapText(tester, 'Iz mojih recepata');
    await tapText(tester, 'Sarma');

    expect(find.text('Pregled izmena'), findsOneWidget);
    expect(find.text('Ručak 4.11. → Sarma'), findsOneWidget);
    await tapText(tester, 'Prihvati');

    expect(find.text('Jelo je zamenjeno.'), findsOneWidget);
    expect(find.text('Sarma'), findsWidgets);
    expect(find.text('Ručak 4.11.'), findsNothing);
  });

  testTavli('ponovni predlog ne dira zaključane ni prošle obroke', (
    tester,
  ) async {
    // Danas je sreda: 2. i 3. su prošli; 4. zaključavamo; menjaju se 5–8.
    final app = await pumpPlan(
      tester,
      size: wide,
      ai: [
        aiAnswer({
          'meals': [
            for (var d = 5; d <= 8; d++)
              {
                'date': '2026-11-0$d',
                'meal': 'lunch',
                'recipeId': null,
                'title': 'Novo $d',
              },
          ],
        }),
        aiAnswer({
          'recipes': [for (var d = 5; d <= 7; d++) recipeJson('Novo $d')],
        }),
        aiAnswer({
          'recipes': [recipeJson('Novo 8')],
        }),
      ],
    );
    await tapText(tester, 'Ručak 4.11.');
    await tapText(tester, 'Zaključaj');
    await backToPlan(tester);

    await tapText(tester, 'Ponovo predloži');

    expect(find.text('Pregled izmena'), findsOneWidget);
    expect(find.textContaining('umesto: Ručak 5.11.'), findsOneWidget);
    expect(find.textContaining('Ručak 4.11.'), findsNothing);
    expect(find.text('Promeni izbore'), findsNothing);
    final outline = app.adapter.requests.first.data.toString();
    expect(outline, isNot(contains('2026-11-04')));
    expect(outline, isNot(contains('2026-11-02')));

    await tapText(tester, 'Prihvati');

    expect(location(tester), '/plan');
    expect(find.text('Izmene su sačuvane.'), findsOneWidget);
    await show(tester, 'Ručak 2.11.');
    await show(tester, 'Ručak 4.11.');
    await show(tester, 'Novo 5');
    expect(find.text('Ručak 5.11.'), findsNothing);
  });
}
