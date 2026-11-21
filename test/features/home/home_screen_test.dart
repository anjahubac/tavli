import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tavli/account/auth_controller.dart';
import 'package:tavli/app/router.dart' show homeLocation;
import 'package:tavli/data/database.dart';
import 'package:tavli/data/meal_plan_repository.dart';
import 'package:tavli/data/shopping_repository.dart';
import 'package:tavli/domain/meal_plan.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/domain/shopping_source.dart';
import 'package:tavli/features/home/home_today.dart';
import 'package:tavli/features/planning/planning_providers.dart';
import 'package:tavli/features/recipes/recipe_providers.dart';
import 'package:tavli/providers.dart';
import 'package:tavli/sync/synced_writer.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/test_app.dart';

/// Petak, 13. novembar 2026, posle podne.
final now = DateTime(2026, 11, 13, 15);
final today = CivilDate(2026, 11, 13);

const _titles = {
  MealType.breakfast: 'Ovsena kaša sa jabukom',
  MealType.lunch: 'Pasulj prebranac',
  MealType.dinner: 'Musaka od krompira',
};

Future<MealPlanRepository> _repo(AppDatabase db) async {
  final account = await db.select(db.accounts).getSingle();
  final scope = AccountScope(
    userId: account.userId,
    householdId: account.householdId,
  );
  final writer = SyncedWriter(db, accountId: scope.userId);
  return MealPlanRepository(
    db,
    scope: scope,
    writer: writer,
    shopping: ShoppingRepository(db, scope: scope, writer: writer),
    clock: () => DateTime.utc(2026, 11),
  );
}

/// Plan od danas do sutra: doručak, ručak i večera; [cooked] današnji
/// obroci su skuvani.
Future<void> seedPlan(
  AppDatabase db, {
  Set<MealType> cooked = const {},
  DateRange? range,
}) async {
  final repo = await _repo(db);
  final request = PlanRequest(
    range: range ?? DateRange(today, today.addDays(1)),
    mealTypes: _titles.keys.toSet(),
    servings: 4,
  );
  String title(MealSlot s) => s.date == today
      ? _titles[s.type]!
      : 'Sutra ${s.type.label.toLowerCase()}';
  final planId = await repo.approve(
    PlanDraft(
      request: request,
      proposals: {
        for (final s in request.slots)
          s: SlotProposal(title: title(s), draftRecipeKey: title(s)),
      },
      newRecipes: {
        for (final s in request.slots)
          title(s): RecipeSnapshot(
            title: title(s),
            baseServings: 4,
            prepMinutes: 75,
            ingredients: const [],
            steps: const ['Skuvaj.'],
          ),
      },
    ),
  );
  final entries = await (db.select(
    db.mealPlanEntries,
  )..where((t) => t.planId.equals(planId))).get();
  for (final e in entries) {
    final type = MealType.tryParse(e.mealType);
    if (CivilDate.fromWire(e.date) == today && cooked.contains(type)) {
      await repo.setCooked(e.id, cooked: true);
    }
  }
}

Future<TestApp> pumpHome(
  WidgetTester tester, {
  Size size = phone,
  FakeBackend? backend,
  Future<void> Function(AppDatabase db)? setup,
}) => pumpTavli(
  tester,
  size: size,
  location: homeLocation,
  backend: backend,
  setup: setup,
  overrides: [clockProvider.overrideWithValue(() => now)],
);

PlannedMeal _meal(MealType type, {bool cooked = false}) => PlannedMeal(
  id: type.name,
  planId: 'p',
  slot: MealSlot(today, type),
  servings: 2,
  isCooked: cooked,
);

void main() {
  test('sledeći je prvi neskuvan obrok; bez njega su svi skuvani', () {
    final day = HomeDay(
      date: today,
      hasPlans: true,
      today: [
        _meal(MealType.breakfast, cooked: true),
        _meal(MealType.lunch),
        _meal(MealType.dinner),
      ],
    );
    expect(day.next?.id, 'lunch');
    expect(day.allCooked, isFalse);

    final done = HomeDay(
      date: today,
      hasPlans: true,
      today: [_meal(MealType.breakfast, cooked: true)],
    );
    expect(done.next, isNull);
    expect(done.allCooked, isTrue);
    expect(HomeDay(date: today, hasPlans: true).allCooked, isFalse);
  });

  testTavli('bez plana: jedna akcija „Napravi plan“', (tester) async {
    await pumpHome(tester);
    expect(find.text('Još nema plana obroka'), findsOneWidget);
    await tapButton(tester, 'Napravi plan');
    expect(find.text('Još nema plana obroka'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testTavli('plan bez današnjih obroka nudi plan, ne pravljenje novog', (
    tester,
  ) async {
    await pumpHome(
      tester,
      setup: (db) =>
          seedPlan(db, range: DateRange(today.addDays(2), today.addDays(3))),
    );
    expect(find.text('Za danas nema obroka u planu'), findsOneWidget);
    expect(button('Otvori plan'), findsOneWidget);
    expect(button('Napravi plan'), findsNothing);
  });

  testTavli('skuvani zasenčeni, sledeći istaknut sa „Kuvaj“, pa sutra', (
    tester,
  ) async {
    await pumpHome(
      tester,
      setup: (db) => seedPlan(db, cooked: {MealType.breakfast}),
    );

    expect(find.text('Petak, 13. novembar'), findsOneWidget);
    expect(find.text('Danas'), findsOneWidget);
    expect(find.text('Doručak · skuvano'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Ovsena kaša sa jabukom'),
        matching: find.byWidgetPredicate(
          (w) => w is TavliCard && w.variant == TavliCardVariant.cooked,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('SLEDEĆE · RUČAK'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Pasulj prebranac'),
        matching: find.byWidgetPredicate(
          (w) => w is TavliCard && w.variant == TavliCardVariant.highlighted,
        ),
      ),
      findsOneWidget,
    );
    expect(button('Kuvaj'), findsOneWidget);
    expect(button('Skuvano'), findsOneWidget);
    // Kuvaj i Skuvano su iste visine.
    expect(
      tester.getSize(button('Kuvaj')).height,
      tester.getSize(button('Skuvano')).height,
    );
    expect(find.text('Musaka od krompira'), findsOneWidget);
    expect(find.text('SUTRA'), findsOneWidget);
    expect(
      find.text('Sutra doručak · Sutra ručak · Sutra večera'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testTavli('„Skuvano“ i „Poništi“ rade bez mreže i šalju jedan događaj', (
    tester,
  ) async {
    final backend = FakeBackend();
    final server = backend.server..offline = true;
    await pumpHome(
      tester,
      backend: backend,
      setup: (db) => seedPlan(db, cooked: {MealType.breakfast}),
    );
    final container = ProviderScope.containerOf(
      tester.element(button('Kuvaj')),
    );
    final sync = container.read(syncEngineProvider)!;
    await tapButton(tester, 'Skuvano');

    expect(find.text('Ručak · skuvano'), findsOneWidget);
    expect(find.text('SLEDEĆE · VEČERA'), findsOneWidget);
    expect(find.text('Skuvano: Pasulj prebranac'), findsOneWidget);
    await sync.push();
    expect(server.rows('cooked_events'), isEmpty);

    await tester.tap(find.text('Poništi'));
    await tester.pumpAndSettle();
    expect(find.text('Ručak · skuvano'), findsNothing);
    expect(find.text('SLEDEĆE · RUČAK'), findsOneWidget);

    server.offline = false;
    await sync.push();
    await sync.pull();
    await sync.push();
    await tester.pumpAndSettle();
    final event = server.rows('cooked_events').single;
    expect(event['undone_at'], isNotNull);
    expect(find.text('SLEDEĆE · RUČAK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testTavli('„Kuvaj“ otvara obrok sa koracima pripreme', (tester) async {
    await pumpHome(tester, setup: seedPlan);
    expect(find.text('SLEDEĆE · DORUČAK'), findsOneWidget);
    await tapButton(tester, 'Kuvaj');
    expect(find.text('Priprema'), findsOneWidget);
    expect(find.text('1. Skuvaj.'), findsOneWidget);
  });

  testTavli('„Kuvaj“ otvara korake na širokom ekranu', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpHome(tester, size: wide, setup: seedPlan);
    await tapButton(tester, 'Kuvaj');
    expect(find.text('Priprema'), findsOneWidget);
    expect(find.text('1. Skuvaj.'), findsOneWidget);
  });

  testTavli('svi današnji obroci skuvani', (tester) async {
    await pumpHome(
      tester,
      setup: (db) => seedPlan(db, cooked: _titles.keys.toSet()),
    );
    expect(find.text('Svi današnji obroci su skuvani.'), findsOneWidget);
    expect(button('Kuvaj'), findsNothing);
    expect(find.text('Večera · skuvano'), findsOneWidget);
  });

  testTavli('greška čitanja nije prazno stanje; ponovni pokušaj', (
    tester,
  ) async {
    var attempts = 0;
    await pumpTavli(
      tester,
      location: homeLocation,
      overrides: [
        clockProvider.overrideWithValue(() => now),
        mealPlansProvider.overrideWith((ref) {
          if (attempts++ == 0) {
            return Stream.error(StateError('synthetic failure'));
          }
          return Stream.value([]);
        }),
      ],
    );
    expect(
      find.text('Današnji obroci trenutno ne mogu da se prikažu.'),
      findsOneWidget,
    );
    expect(find.text('Još nema plana obroka'), findsNothing);
    await tapButton(tester, 'Pokušaj ponovo');
    expect(find.text('Još nema plana obroka'), findsOneWidget);
  });

  testTavli('širok ekran: skuvani u dve kolone, „Sutra“ desno', (tester) async {
    await pumpHome(
      tester,
      size: wide,
      setup: (db) => seedPlan(db, cooked: {MealType.breakfast, MealType.lunch}),
    );
    final breakfast = tester.getRect(find.text('Doručak · skuvano'));
    final lunch = tester.getRect(find.text('Ručak · skuvano'));
    expect(lunch.top, breakfast.top);
    expect(lunch.left, greaterThan(breakfast.right));

    final next = tester.getRect(find.text('Musaka od krompira'));
    final tomorrow = tester.getRect(find.text('Sutra ručak'));
    expect(tomorrow.left, greaterThan(next.right));
    expect(find.text('SUTRA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), wide]) {
    testTavli('${size.width} px, tekst 2×: sve staje i pomera se', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpHome(
        tester,
        size: size,
        setup: (db) => seedPlan(db, cooked: {MealType.breakfast}),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(button('Kuvaj'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
