import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/ai_router.dart';
import 'package:tavli/ai/chain_config.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/ai/meal_plan_ai.dart';
import 'package:tavli/ai/model_status_store.dart';
import 'package:tavli/domain/allergen_group.dart';
import 'package:tavli/domain/cuisine_preferences.dart';
import 'package:tavli/domain/meal_plan.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/domain/planning_tastes.dart';
import 'package:tavli/domain/recipe.dart';
import 'package:tavli/domain/recipe_labels.dart';

import 'meal_plan_ai_test.dart'
    show
        ScriptedClient,
        goodAnswer,
        isOutline,
        libraryRecipe,
        model,
        monday,
        slotsIn,
        weekRequest;

const fishId = '33333333-3333-4333-8333-333333333333';
const mushroomId = '44444444-4444-4444-8444-444444444444';

/// Ukusi redom iz [answers]; poslednji se ponavlja. Izuzetak se baca.
class FakeTastes implements PlanningTastesSource {
  FakeTastes(this.answers);
  final List<Object> answers;
  int calls = 0;

  @override
  Future<PlanningTastes> current() async {
    final next = answers[calls < answers.length ? calls : answers.length - 1];
    calls++;
    if (next is Exception) throw next;
    return next as PlanningTastes;
  }
}

final noFish = PlanningTastes(
  dislikedFoodIds: {fishId},
  dislikedDishKinds: {DishKind.soup},
  likedCuisines: {Cuisine.italian},
  likedFoodIds: {mushroomId},
  foodNames: {fishId: 'riba', mushroomId: 'pečurke'},
);

Recipe withFood(String id, String title, String foodId) =>
    libraryRecipe(id, title).copyWith(
      ingredients: [
        Ingredient(
          name: title,
          quantity: 1,
          unit: 'kg',
          link: IngredientLink(
            foodId: foodId,
            matchedKey: title,
            linkSource: LinkSource.confirmed,
          ),
        ),
      ],
    );

List<String> libraryIdsIn(AIRequest r) {
  final m = RegExp(r'^Library: (.*)$', multiLine: true).firstMatch(r.prompt);
  return [
    for (final e in jsonDecode(m![1]!) as List<dynamic>)
      (e as Map<String, dynamic>)['id'] as String,
  ];
}

void main() {
  late ScriptedClient client;

  MealPlanAI planner(PlanningTastesSource? tastes) => MealPlanAI(
    AIRouter(
      config: () => const ChainConfig(vision: [model], text: [model]),
      client: client,
      keys: OwnKeySource(InMemoryKeyStore({AIProvider.gemini: 'g-key'})),
      status: InMemoryModelStatusStore(),
      clock: () => DateTime.utc(2026, 11, 2, 12),
    ),
    tastes: tastes,
  );

  setUp(() => client = ScriptedClient(goodAnswer));

  test('ukusi idu u upit kao savet, bez ljudi i alergena', () async {
    await planner(FakeTastes([noFish])).propose(weekRequest());

    final outline = client.requests.firstWhere(isOutline).prompt;
    expect(outline, contains('Household tastes (advice, not a safety rule'));
    expect(
      outline,
      contains(
        '- avoid whenever another fitting dish exists: '
        'foods ["riba"]; dish kinds ["soup"]',
      ),
    );
    expect(
      outline,
      contains(
        '- prefer when they fit the rules: foods ["pečurke"]; '
        'cuisines ["italian"]',
      ),
    );
    for (final group in AllergenGroup.values) {
      expect(outline, isNot(contains('"${group.code}"')));
    }
    expect(outline, isNot(contains(fishId)));

    final summaries = client.requests.where((r) => !isOutline(r)).first;
    expect(
      summaries.prompt,
      contains(
        'leave out these ingredients the household dislikes (data): '
        '["riba"]',
      ),
    );
  });

  test('bez podeljenih ukusa upit je kao ranije', () async {
    await planner(FakeTastes([PlanningTastes.none])).propose(weekRequest());
    for (final r in client.requests) {
      expect(r.prompt, isNot(contains('Household tastes')));
      expect(r.prompt, isNot(contains('dislikes (data)')));
    }
  });

  test('namirnica bez naziva u katalogu se ne navodi', () async {
    final unnamed = PlanningTastes(dislikedFoodIds: {fishId});
    await planner(FakeTastes([unnamed])).propose(weekRequest());
    final outline = client.requests.firstWhere(isOutline).prompt;
    expect(outline, isNot(contains('Household tastes')));
    expect(outline, isNot(contains(fishId)));
  });

  test(
    'recept sa ribom ide na kraj biblioteke i ispada iznad granice',
    () async {
      final fish = withFood('fish', 'Riblja čorba', fishId);
      final others = [
        for (var i = 0; i < maxLibraryInPrompt; i++)
          libraryRecipe('r$i', 'Jelo $i'),
      ];

      await planner(FakeTastes([noFish]))
          .propose(weekRequest(), library: [fish, ...others]);
      final ids = libraryIdsIn(client.requests.firstWhere(isOutline));
      expect(ids, hasLength(maxLibraryInPrompt));
      expect(ids, isNot(contains('fish')));

      // Bez ukusa isti recept je prvi: ništa se ne izbacuje bez razloga.
      client.requests.clear();
      await planner(null).propose(weekRequest(), library: [fish, ...others]);
      expect(libraryIdsIn(client.requests.firstWhere(isOutline)).first, 'fish');
    },
  );

  test('kad nema drugih, recept sa ribom ostaje ponuđen (savet)', () async {
    final fish = withFood('fish', 'Riblja čorba', fishId);
    final beans = libraryRecipe('beans', 'Pasulj');
    await planner(FakeTastes([noFish]))
        .propose(weekRequest(), library: [fish, beans]);
    expect(libraryIdsIn(client.requests.firstWhere(isOutline)), [
      'beans',
      'fish',
    ]);
  });

  test('rezervni sačuvan recept bira jelo bez ribe', () async {
    final day = PlanRequest(
      range: DateRange(monday, monday),
      mealTypes: const {MealType.lunch, MealType.dinner},
    );
    Recipe labelled(Recipe r, String weight, String kind) => r.copyWith(
      labels: RecipeLabels(weight: weight, dishKind: kind, source: 'user'),
    );
    // AI dva puta predloži dva jaka jela; večera pada na pravilu.
    client.handler = (r) => isOutline(r)
        ? jsonEncode({
            'meals': [
              for (final s in slotsIn(r))
                {
                  ...s,
                  'recipeId': null,
                  'title': s['meal'] == 'lunch' ? 'Gulaš' : 'Sarma',
                  'weight': 'hearty',
                  'dishKind': 'cooked',
                },
            ],
          })
        : goodAnswer(r);

    final draft = await planner(FakeTastes([noFish])).propose(
      day,
      library: [
        labelled(
          withFood('fish', 'Tunjevina salata', fishId),
          'light',
          'salad',
        ),
        labelled(libraryRecipe('ok', 'Salata sa jajima'), 'light', 'salad'),
      ],
    );

    expect(
      draft.proposals[MealSlot(monday, MealType.dinner)]!.libraryRecipeId,
      'ok',
    );
  });

  test('ukusi se čitaju sveže pre svakog rasporeda; povučen pristanak '
      'važi odmah', () async {
    final source = FakeTastes([noFish, PlanningTastes.none]);
    final twoWeeks = PlanRequest(
      range: DateRange(monday, monday.addDays(13)),
      mealTypes: const {MealType.lunch},
    );

    await planner(source).propose(twoWeeks);

    final outlines = client.requests.where(isOutline).toList();
    expect(outlines, hasLength(2));
    expect(outlines[0].prompt, contains('Household tastes'));
    expect(outlines[1].prompt, isNot(contains('Household tastes')));
    // Dva rasporeda i jedno čitanje pre novih recepata.
    expect(source.calls, 3);
    for (final r in client.requests.where((r) => !isOutline(r))) {
      expect(r.prompt, isNot(contains('dislikes (data)')));
    }
  });

  test('zamena jednog jela koristi iste ukuse', () async {
    final slot = MealSlot(monday, MealType.lunch);
    final request = PlanRequest(
      range: DateRange(monday, monday.addDays(6)),
      mealTypes: const {MealType.lunch},
      only: {slot},
    );
    await planner(FakeTastes([noFish])).propose(request);
    final outline = client.requests.firstWhere(isOutline);
    expect(slotsIn(outline), hasLength(1));
    expect(outline.prompt, contains('foods ["riba"]'));
  });

  test('ukusi nedostupni: plan se pravi bez njih i nacrt to kaže', () async {
    final draft = await planner(FakeTastes([const PlanningTastesUnavailable()]))
        .propose(weekRequest());

    expect(draft.isComplete, isTrue);
    expect(draft.withoutTastes, isTrue);
    expect(
      client.requests.any((r) => r.prompt.contains('Household tastes')),
      isFalse,
    );
  });

  test('server odbio (drugo domaćinstvo): plan staje pre AI-ja', () async {
    await expectLater(
      planner(FakeTastes([const PlanningTastesDenied()]))
          .propose(weekRequest()),
      throwsA(
        isA<PlanGenerationFailed>().having(
          (e) => e.error,
          'error',
          isA<PlanningTastesDenied>(),
        ),
      ),
    );
    expect(client.requests, isEmpty);
  });

  test('bez izvora ukusa (bez prijave) plan radi kao ranije', () async {
    final draft = await planner(null).propose(weekRequest());
    expect(draft.isComplete, isTrue);
    expect(draft.withoutTastes, isFalse);
  });

  group('omiljeni recepti (TRELLO-44)', () {
    test('omiljeni idu napred po broju članova; koji neko ne voli ostaje '
        'na kraju', () async {
      final tastes = PlanningTastes(
        dislikedFoodIds: {fishId},
        favoriteCounts: {'two': 2, 'one': 1, 'fish': 3, 'nema-u-biblioteci': 1},
      );
      await planner(FakeTastes([tastes])).propose(
        weekRequest(),
        library: [
          libraryRecipe('plain', 'Pasulj'),
          libraryRecipe('one', 'Gibanica'),
          withFood('fish', 'Riblja čorba', fishId),
          libraryRecipe('two', 'Sarma'),
        ],
      );
      final outline = client.requests.firstWhere(isOutline);
      expect(libraryIdsIn(outline), ['two', 'one', 'plain', 'fish']);
      // U upitu samo omiljeni iz ponuđene biblioteke, najvoljeniji prvi.
      expect(
        outline.prompt,
        contains(
          'household favorites, by Library id: use them more often when '
          'they fit the rules, but each at most once in 7 days: '
          '["fish","two","one"]',
        ),
      );
      expect(outline.prompt, isNot(contains('nema-u-biblioteci')));
    });

    test(
      'omiljen recept predložen dvaput u nedelji: drugi put se menja',
      () async {
        final mon = MealSlot(monday, MealType.lunch);
        final fri = MealSlot(monday.addDays(4), MealType.lunch);
        var outlines = 0;
        client.handler = (r) {
          if (!isOutline(r)) return goodAnswer(r);
          outlines++;
          return jsonEncode({
            'meals': [
              for (final s in slotsIn(r))
                {
                  ...s,
                  'recipeId':
                      outlines == 1 &&
                          (s['date'] == '2026-11-02' ||
                              s['date'] == '2026-11-06')
                      ? 'fav'
                      : null,
                  'title': 'Jelo ${s['date']}',
                },
            ],
          });
        };

        final draft = await planner(
          FakeTastes([
            PlanningTastes(favoriteCounts: {'fav': 2}),
          ]),
        ).propose(weekRequest(), library: [libraryRecipe('fav', 'Sarma')]);

        expect(draft.proposals[mon]!.libraryRecipeId, 'fav');
        expect(draft.proposals[fri]!.libraryRecipeId, isNull);
        final retry = client.requests.where(isOutline).last;
        expect(slotsIn(retry).map((s) => s['date']), ['2026-11-06']);
      },
    );

    test(
      'bez ukusa isti recept posle 4 dana ostaje (pravilo 3 dana)',
      () async {
        client.handler = (r) => isOutline(r)
            ? jsonEncode({
                'meals': [
                  for (final s in slotsIn(r))
                    {
                      ...s,
                      'recipeId':
                          s['date'] == '2026-11-02' || s['date'] == '2026-11-06'
                          ? 'fav'
                          : null,
                      'title': 'Jelo ${s['date']}',
                    },
                ],
              })
            : goodAnswer(r);
        final draft = await planner(null)
            .propose(weekRequest(), library: [libraryRecipe('fav', 'Sarma')]);
        expect(
          draft
              .proposals[MealSlot(monday.addDays(4), MealType.lunch)]!
              .libraryRecipeId,
          'fav',
        );
        expect(client.requests.where(isOutline), hasLength(1));
      },
    );
  });
}
