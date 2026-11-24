import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavli/ai/ai_models.dart';
import 'package:tavli/ai/ai_router.dart';
import 'package:tavli/ai/chain_config.dart';
import 'package:tavli/ai/key_store.dart';
import 'package:tavli/ai/meal_plan_ai.dart';
import 'package:tavli/ai/model_status_store.dart';
import 'package:tavli/domain/allergen_group.dart';
import 'package:tavli/domain/meal_plan.dart';
import 'package:tavli/domain/plan_calendar.dart';
import 'package:tavli/domain/plan_safety.dart';

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

/// Provere redom iz [answers]; poslednja se ponavlja. Izuzetak se baca.
class FakeSafety implements PlanSafetySource {
  FakeSafety(this.answers);
  final List<Object> answers;
  final asked = <Set<String>>[];

  @override
  Future<PlanSafety> check(Set<String> recipeIds) async {
    final next =
        answers[asked.length < answers.length
            ? asked.length
            : answers.length - 1];
    asked.add(recipeIds);
    if (next is Exception) throw next;
    return next as PlanSafety;
  }
}

/// Raspored u kom je svako mesto recept [id] (ili prazno kad je null).
String outlineWith(AIRequest r, String? id) => jsonEncode({
  'meals': [
    for (final s in slotsIn(r))
      {'date': s['date'], 'meal': s['meal'], 'recipeId': id, 'title': ''},
  ],
});

List<String> libraryIdsIn(AIRequest r) {
  final m = RegExp(r'^Library: (.*)$', multiLine: true).firstMatch(r.prompt);
  return [
    for (final e in jsonDecode(m![1]!) as List<dynamic>)
      (e as Map<String, dynamic>)['id'] as String,
  ];
}

void main() {
  late ScriptedClient client;

  MealPlanAI planner(PlanSafetySource? safety) => MealPlanAI(
    AIRouter(
      config: () => const ChainConfig(vision: [model], text: [model]),
      client: client,
      keys: OwnKeySource(InMemoryKeyStore({AIProvider.gemini: 'g-key'})),
      status: InMemoryModelStatusStore(),
      clock: () => DateTime.utc(2026, 11, 2, 12),
    ),
    safety: safety,
  );

  final library = [
    libraryRecipe('safe', 'Pasulj'),
    libraryRecipe('satay', 'Piletina sa kikirikijem'),
  ];
  final day = PlanRequest(
    range: DateRange(monday, monday),
    mealTypes: const {MealType.lunch},
  );
  final lunch = MealSlot(monday, MealType.lunch);

  setUp(() => client = ScriptedClient(goodAnswer));

  test('bez alergija u domaćinstvu plan je kao ranije', () async {
    final safety = FakeSafety([const PlanSafety.unrestricted()]);
    final draft = await planner(safety).propose(day, library: library);

    final outline = client.requests.firstWhere(isOutline);
    expect(libraryIdsIn(outline), ['safe', 'satay']);
    expect(outline.prompt, contains('or null for a new dish'));
    expect(draft.proposals[lunch]!.isNew, isTrue);
    expect(draft.householdRestricted, isFalse);
    expect(draft.isComplete, isTrue);
    // Server dobija samo id-jeve recepata.
    expect(safety.asked.first, {'safe', 'satay'});
  });

  test('sa alergijom AI vidi samo bezbedne i ne izmišlja jela', () async {
    final safety = FakeSafety([
      const PlanSafety.restricted({'safe'}),
    ]);
    client.handler = (r) => isOutline(r) ? outlineWith(r, 'safe') : '';

    final draft = await planner(safety).propose(day, library: library);

    final outline = client.requests.single;
    expect(libraryIdsIn(outline), ['safe']);
    expect(outline.prompt, contains('never invent ids or new dishes'));
    expect(outline.prompt, isNot(contains('null for a new dish')));
    for (final group in AllergenGroup.values) {
      expect(outline.prompt, isNot(contains('"${group.code}"')));
    }
    expect(draft.proposals[lunch]!.libraryRecipeId, 'safe');
    expect(draft.householdRestricted, isTrue);
  });

  test(
    'kad nijedan bezbedan recept ne odgovara, mesto ostaje prazno',
    () async {
      final safety = FakeSafety([const PlanSafety.restricted({})]);
      client.handler = (r) => isOutline(r) ? outlineWith(r, null) : '';

      final draft = await planner(safety)
          .propose(weekRequest(), library: library);

      expect(draft.proposals, isEmpty);
      expect(draft.missingSlots, hasLength(7));
      expect(draft.householdRestricted, isTrue);
      // Nema novih recepata, pa ni zahteva za njihove detalje.
      expect(client.requests.every(isOutline), isTrue);
    },
  );

  test('novo jelo ili nebezbedan recept u odgovoru se odbija', () {
    Map<MealSlot, SlotProposal> parse(Map<String, Object?> meal) =>
        parseOutline(
          {
            'meals': [
              {'date': monday.toString(), 'meal': 'lunch', ...meal},
            ],
          },
          slots: [lunch],
          library: const {'safe': 'Pasulj'},
          allowed: const {
            MealType.lunch: {'safe'},
          },
          allowNew: false,
        );
    expect(parse({'recipeId': 'safe'})[lunch]!.libraryRecipeId, 'safe');
    // Naziv uz null se ne prihvata kao novo jelo: mesto je prazno.
    expect(parse({'recipeId': null, 'title': 'Satay'}), isEmpty);
    expect(() => parse({'recipeId': 'satay'}), throwsFormatException);
  });

  test('završna provera izbacuje recept koji više nije bezbedan', () async {
    // Posle rasporeda neko je dodao alergiju ili izmenio recept.
    final safety = FakeSafety([
      const PlanSafety.unrestricted(),
      const PlanSafety.restricted({}),
    ]);
    client.handler = (r) => isOutline(r) ? outlineWith(r, 'satay') : '';

    final draft = await planner(safety).propose(day, library: library);

    expect(safety.asked, hasLength(2));
    expect(safety.asked.last, {'satay'});
    expect(draft.proposals, isEmpty);
    expect(draft.householdRestricted, isTrue);
  });

  test('bez provere nema plana i nema poziva AI-ju', () async {
    final safety = FakeSafety([const PlanSafetyUnavailable()]);
    await expectLater(
      planner(safety).propose(day, library: library),
      throwsA(
        isA<PlanGenerationFailed>().having(
          (e) => e.error,
          'error',
          isA<PlanSafetyUnavailable>(),
        ),
      ),
    );
    expect(client.requests, isEmpty);
  });

  test('zamena jednog jela prolazi istu proveru', () async {
    final safety = FakeSafety([
      const PlanSafety.restricted({'safe'}),
    ]);
    client.handler = (r) => isOutline(r) ? outlineWith(r, 'safe') : '';
    final request = PlanRequest(
      range: day.range,
      mealTypes: day.mealTypes,
      only: {lunch},
    );
    final draft = await planner(safety).propose(
      request,
      library: library,
      resume: PlanDraft(request: request),
    );
    expect(libraryIdsIn(client.requests.single), ['safe']);
    expect(draft.proposals[lunch]!.libraryRecipeId, 'safe');
    expect(safety.asked, hasLength(2));
  });
}
