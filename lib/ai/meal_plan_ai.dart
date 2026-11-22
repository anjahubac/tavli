import '../domain/meal_plan.dart';
import '../domain/meal_rules.dart';
import '../domain/plan_calendar.dart';
import '../domain/recipe.dart';
import '../domain/recipe_labels.dart';
import '../domain/shopping_demand.dart' show maxServings;
import '../domain/shopping_source.dart';
import 'ai_models.dart';
import 'ai_response_validator.dart';
import 'ai_router.dart';
import 'meal_plan_prompts.dart';

/// Najviše novih recepata u jednom zahtevu.
const recipeSummaryBatch = 3;

/// Najviše recepata iz biblioteke koji se nude AI-ju u jednom rasporedu.
const maxLibraryInPrompt = 60;

/// Osoba je prekinula generisanje. Proverava se između grupa, a router je
/// proverava i pre svakog poziva modela (i pre popravke odgovora).
class PlanCancellation extends AICancellation {}

/// Grupa nije uspela; [draft] ima sve što je gotovo pre toga.
class PlanGenerationFailed implements Exception {
  const PlanGenerationFailed(this.draft, this.error);

  final PlanDraft draft;
  final Object error;

  @override
  String toString() => 'PlanGenerationFailed: $error';
}

/// Generisanje je prekinuto; [draft] ima sve što je gotovo pre prekida.
class PlanGenerationCancelled implements Exception {
  const PlanGenerationCancelled(this.draft);

  final PlanDraft draft;
}

/// Predlaže plan obroka preko [AIRouter]-a: raspored po nedeljnim delovima,
/// pa sažeci novih recepata u malim grupama. Ništa ne čuva; nacrt ostaje
/// u sesiji dok ga osoba ne odobri.
class MealPlanAI {
  MealPlanAI(this._router);

  final AIRouter _router;

  /// Vraća pun nacrt. Kad grupa ne uspe baca [PlanGenerationFailed], a kad
  /// je [cancel] prekinut [PlanGenerationCancelled]; oba nose gotov deo,
  /// koji se predaje kao [resume] da se traži samo ono što nedostaje.
  Future<PlanDraft> propose(
    PlanRequest request, {
    List<Recipe> library = const [],
    PlanDraft? resume,
    PlanCancellation? cancel,
    void Function(PlanDraft draft)? onProgress,
  }) async {
    if (resume != null && !identical(resume.request, request)) {
      throw ArgumentError('Nastavak pripada drugom zahtevu');
    }
    var draft = resume ?? PlanDraft(request: request);
    final offered = library.take(maxLibraryInPrompt).toList();
    final byId = {for (final r in offered) r.id: r};

    Future<T> step<T>(Future<T> Function() run) async {
      if (cancel?.isCancelled ?? false) throw PlanGenerationCancelled(draft);
      try {
        return await run();
      } on AICancelled {
        throw PlanGenerationCancelled(draft);
      } on Object catch (e) {
        throw PlanGenerationFailed(draft, e);
      }
    }

    final requested = request.slots.toSet();
    // Jela koja ostaju: iz sačuvanog plana i, kod zamene u nacrtu, ostali
    // predlozi. Ne predlažu se ponovo, ali ih pravila gledaju.
    Map<MealSlot, MealFacts> keptFacts() => {
      ...request.kept,
      for (final e in draft.proposals.entries)
        if (!requested.contains(e.key)) e.key: e.value.facts,
    };
    final around = [
      for (final e in keptFacts().entries)
        (slot: e.key, title: e.value.title ?? '', weight: e.value.weight),
    ]..sort((a, b) => a.slot.compareTo(b.slot));

    // Za recept iz biblioteke važe sačuvane oznake, ne one koje AI kaže.
    SlotProposal withStoredLabels(SlotProposal p) {
      final labels = byId[p.libraryRecipeId]?.labels;
      if (labels == null) return p;
      return SlotProposal(
        title: p.title,
        libraryRecipeId: p.libraryRecipeId,
        weight: labels.weightValue ?? p.weight,
        dishKind: labels.dishKindValue ?? p.dishKind,
      );
    }

    void put(Map<MealSlot, SlotProposal> proposals) {
      draft = draft.copyWith(
        proposals: {...draft.proposals, ...proposals},
        libraryRecipes: {
          ...draft.libraryRecipes,
          for (final id
              in proposals.values.map((p) => p.libraryRecipeId).nonNulls)
            id: RecipeSnapshot.fromRecipe(byId[id]!),
        },
      );
    }

    Future<Map<MealSlot, SlotProposal>> outline(
      List<MealSlot> slots, {
      List<String> rejected = const [],
    }) async {
      final planned = {for (final p in draft.proposals.values) p.title};
      final result = await step(
        () => _router.run(
          AIRequest(
            task: AITask.planOutline,
            system: mealPlanSystemPrompt,
            prompt: planOutlinePrompt(
              slots: slots,
              servings: request.servings,
              library: [
                for (final r in offered)
                  (
                    id: r.id,
                    title: r.title,
                    weight: r.labels.weightValue,
                    dishKind: r.labels.dishKindValue,
                  ),
              ],
              alreadyPlanned: planned.toList(),
              around: around,
              rejected: rejected,
              wishes: request.wishes,
              pantry: request.usePantry ? request.pantryNames : const [],
            ),
            temperature: 0.8,
          ),
          (json) => parseOutline(
            json,
            slots: slots,
            library: {for (final r in offered) r.id: r.title},
          ),
          cancel: cancel,
        ),
      );
      return {
        for (final e in result.value.entries) e.key: withStoredLabels(e.value),
      };
    }

    final proposedNow = <MealSlot>{};
    for (final period in weekPeriods(request.range)) {
      final missing = [
        for (final s in draft.missingSlots)
          if (period.range.contains(s.date)) s,
      ];
      if (missing.isEmpty) continue;
      final proposals = await outline(missing);
      put(proposals);
      proposedNow.addAll(proposals.keys);
      onProgress?.call(draft);
    }

    if (proposedNow.isNotEmpty) {
      final before = draft.proposals;
      await _applyRules(
        movable: proposedNow,
        facts: () => {
          ...keptFacts(),
          for (final s in proposedNow) s: draft.proposals[s]!.facts,
        },
        proposals: () => draft.proposals,
        put: put,
        retry: (slots, rejected) => outline(slots, rejected: rejected),
        library: offered,
      );
      if (!identical(before, draft.proposals)) onProgress?.call(draft);
    }

    final missingKeys = draft.missingRecipeKeys;
    final titles = {
      for (final p in draft.proposals.values) ?p.draftRecipeKey: p.title,
    };
    for (var i = 0; i < missingKeys.length; i += recipeSummaryBatch) {
      final batch = [
        for (final key in missingKeys.skip(i).take(recipeSummaryBatch))
          titles[key]!,
      ];
      final result = await step(
        () => _router.run(
          AIRequest(
            task: AITask.recipeSummaries,
            system: mealPlanSystemPrompt,
            prompt: recipeSummariesPrompt(batch),
          ),
          (json) => parseSummaries(json, titles: batch),
          cancel: cancel,
        ),
      );
      draft = draft.copyWith(
        newRecipes: {...draft.newRecipes, ...result.value},
      );
      onProgress?.call(draft);
    }
    return draft;
  }

  /// Pravila rasporeda posle AI odgovora (TRELLO-39), tiho, korak po korak:
  /// 1. ručak i večera koji su samo zamenili mesta vraćaju se na svoje;
  /// 2. za mesta koja i dalje ne prolaze jedan novi AI zahtev, samo za njih;
  /// 3. ako ni to ne prođe, odgovarajući sačuvan recept sa poznatim
  ///    oznakama;
  /// 4. inače jelo ostaje (bez poruke korisniku).
  /// Menjaju se samo [movable] mesta; jela koja ostaju u planu se ne diraju.
  Future<void> _applyRules({
    required Set<MealSlot> movable,
    required Map<MealSlot, MealFacts> Function() facts,
    required Map<MealSlot, SlotProposal> Function() proposals,
    required void Function(Map<MealSlot, SlotProposal>) put,
    required Future<Map<MealSlot, SlotProposal>> Function(
      List<MealSlot> slots,
      List<String> rejected,
    )
    retry,
    required List<Recipe> library,
  }) async {
    List<MealSlot> broken() {
      final breaks = mealRuleBreaks(facts(), movable: movable);
      return [
        for (final s in movable)
          if (breaks[s]?.isNotEmpty ?? false) s,
      ]..sort();
    }

    for (final (lunch, dinner) in lunchDinnerSwaps(facts(), movable)) {
      final current = proposals();
      put({lunch: current[dinner]!, dinner: current[lunch]!});
    }

    var bad = broken();
    if (bad.isEmpty) return;
    try {
      final current = proposals();
      put(await retry(bad, [for (final s in bad) current[s]!.title]));
    } on PlanGenerationFailed {
      // Novi predlog nije uspeo: ostaje prvi, pa ide rezervni korak.
    }

    bad = broken();
    for (final slot in bad) {
      final before = mealRuleBreaks(facts(), movable: movable);
      for (final r in library) {
        final weight = r.labels.weightValue;
        if (weight == null) continue;
        final candidate = SlotProposal(
          title: r.title,
          libraryRecipeId: r.id,
          weight: weight,
          dishKind: r.labels.dishKindValue,
        );
        final after = mealRuleBreaks({
          ...facts(),
          slot: candidate.facts,
        }, movable: movable);
        final fits =
            (after[slot]?.isEmpty ?? true) &&
            after.entries.every(
              (e) =>
                  e.key == slot ||
                  (before[e.key] ?? const {}).containsAll(e.value),
            );
        if (fits) {
          put({slot: candidate});
          break;
        }
      }
    }
  }
}

/// Čita raspored: tačno jedan predlog za svako od [slots]. Baca
/// [FormatException] za mesto koje nedostaje, ponavlja se ili nije traženo,
/// i za id recepta koji nije u [library] (id → naziv).
Map<MealSlot, SlotProposal> parseOutline(
  Map<String, dynamic> json, {
  required List<MealSlot> slots,
  required Map<String, String> library,
}) {
  final meals = json['meals'];
  if (meals is! List) throw const FormatException('Nema rasporeda');
  final wanted = slots.toSet();
  final result = <MealSlot, SlotProposal>{};
  for (final raw in meals) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Pokvaren obrok');
    }
    final date = CivilDate.parse(raw['date'] as String? ?? '');
    final type = MealType.tryParse(raw['meal']);
    if (type == null) throw const FormatException('Nepoznata vrsta obroka');
    final slot = MealSlot(date, type);
    if (!wanted.contains(slot)) {
      throw FormatException('Mesto nije traženo', '$slot');
    }
    if (result.containsKey(slot)) {
      throw FormatException('Mesto se ponavlja', '$slot');
    }
    // Nepoznata ili izostavljena oznaka je null: to jelo se po tom
    // pravilu ne proverava (ne odbija se ceo raspored).
    final weight = DishWeight.tryParse(raw['weight']);
    final dishKind = DishKind.tryParse(raw['dishKind']);
    final id = raw['recipeId'];
    if (id != null) {
      final title = id is String ? library[id] : null;
      if (title == null) throw const FormatException('Nepoznat recept');
      result[slot] = SlotProposal(
        title: title,
        libraryRecipeId: id as String,
        weight: weight,
        dishKind: dishKind,
      );
      continue;
    }
    final title = aiTitle(raw['title']);
    result[slot] = SlotProposal(
      title: title,
      draftRecipeKey: draftRecipeKey(title),
      weight: weight,
      dishKind: dishKind,
    );
  }
  if (result.length != wanted.length) {
    throw const FormatException('Nedostaju mesta u rasporedu');
  }
  return result;
}

/// Čita sažetke: tačno jedan recept za svaki od [titles], po
/// [draftRecipeKey]. Baca [FormatException] za višak, manjak, duplikat,
/// porcije van 1–20 i sastojke koji ne prolaze ugovor (S1–S3).
Map<String, RecipeSnapshot> parseSummaries(
  Map<String, dynamic> json, {
  required List<String> titles,
}) {
  final recipes = json['recipes'];
  if (recipes is! List) throw const FormatException('Nema recepata');
  final wanted = {for (final t in titles) draftRecipeKey(t): t.trim()};
  final result = <String, RecipeSnapshot>{};
  for (final raw in recipes) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Pokvaren recept');
    }
    final key = draftRecipeKey(raw['title'] as String? ?? '');
    if (!wanted.containsKey(key)) {
      throw FormatException('Recept nije tražen', key);
    }
    if (result.containsKey(key)) {
      throw FormatException('Recept se ponavlja', key);
    }
    result[key] = RecipeSnapshot(
      title: wanted[key]!,
      baseServings: aiServings(raw['servings'], max: maxServings, rule: 'S2'),
      prepMinutes: aiPrepMinutes(raw['prepMinutes']),
      ingredients: aiIngredients(raw['ingredients']),
    );
  }
  if (result.length != wanted.length) {
    throw const FormatException('Nedostaju recepti');
  }
  return result;
}
