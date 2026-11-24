import '../domain/meal_plan.dart';
import '../domain/meal_rules.dart';
import '../domain/plan_calendar.dart';
import '../domain/plan_safety.dart';
import '../domain/planning_tastes.dart';
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

/// Najviše recepata u jednoj proveri bezbednosti (granica servera).
const maxSafetyRecipes = 1000;

/// Najviše recepata iz biblioteke koji se nude AI-ju u jednom rasporedu.
/// Deli se na obroke iz rasporeda (obe užine su jedan obrok), pa svaki
/// obrok dobija svoj spisak.
const maxLibraryInPrompt = 60;

/// Da li recept iz biblioteke sme na mesto obroka [type]: oznaka obroka
/// (kad je ima) odgovara, a težina i vrsta jela ne krše pravila mesta.
/// Nepoznata oznaka ne isključuje recept.
bool fitsMeal(Recipe recipe, MealType type) {
  final meals = recipe.labels.mealSet;
  if (meals.isNotEmpty && !meals.contains(suitabilityFor(type))) return false;
  return slotRuleBreaks(
    type,
    MealFacts(
      recipeKey: recipe.id,
      weight: recipe.labels.weightValue,
      dishKind: recipe.labels.dishKindValue,
    ),
  ).isEmpty;
}

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
/// pa sastojci i koraci novih recepata u malim grupama. Ništa ne čuva; nacrt ostaje
/// u sesiji dok ga osoba ne odobri.
///
/// Ukusi članova (`tastes`, TRELLO-41) se čitaju pre svakog rasporeda i pre
/// novih recepata, da povučen pristanak važi odmah. Recepti iz biblioteke
/// sa namirnicom ili vrstom jela koju neko ne voli nude se AI-ju poslednji
/// (savet, ne zabrana). Kad ukusi nisu dostupni, plan se pravi bez njih i
/// nacrt to beleži; kad ih server odbije (drugo domaćinstvo), plan staje.
///
/// Bezbednost (`safety`, TRELLO-43) proverava server pre svakog rasporeda i
/// još jednom pre nego što se nacrt vrati. Kad neko u domaćinstvu ima
/// alergiju, AI bira samo bezbedne sačuvane recepte i ne izmišlja jela;
/// mesto bez takvog recepta ostaje prazno. Bez provere nema ni plana.
class MealPlanAI {
  MealPlanAI(this._router, {this._tastes, this._safety});

  final AIRouter _router;
  final PlanningTastesSource? _tastes;
  final PlanSafetySource? _safety;

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
    final eligible = library
        .where((recipe) => recipe.steps.any((step) => step.trim().isNotEmpty))
        .toList();
    final byId = {for (final r in eligible) r.id: r};
    var tastes = PlanningTastes.none;
    var safety = const PlanSafety.unrestricted();

    // Pre ograničenja broja: omiljeni prvi (više članova, više napred),
    // pa ostali, a recepti koje neko ne voli na kraj, i kad su omiljeni.
    // Unutar grupe redosled biblioteke ostaje.
    List<Recipe> rankedFor(PlanningTastes t) {
      int favorite(Recipe r) => t.dislikes(r) ? 0 : t.favoriteCounts[r.id] ?? 0;
      // Stabilno: kod istog broja članova ostaje redosled biblioteke.
      final liked =
          [
            for (final (i, r) in eligible.indexed)
              if (favorite(r) > 0 && safety.allows(r.id)) (i, r),
          ]..sort((a, b) {
            final byCount = favorite(b.$2).compareTo(favorite(a.$2));
            return byCount != 0 ? byCount : a.$1.compareTo(b.$1);
          });
      return [
        for (final (_, r) in liked) r,
        ...eligible.where(
          (r) => favorite(r) == 0 && !t.dislikes(r) && safety.allows(r.id),
        ),
        ...eligible.where((r) => t.dislikes(r) && safety.allows(r.id)),
      ];
    }

    var ranked = rankedFor(tastes);

    // Spisak po obroku: prvo se izbace recepti koji ne odgovaraju obroku,
    // pa tek onda ograničenje broja, da 60 nepogodnih ne sakrije pogodan.
    Map<MealType, List<Recipe>> candidatesFor(Iterable<MealType> types) {
      final groups = {for (final t in types) suitabilityFor(t)};
      final perGroup = groups.isEmpty ? 0 : maxLibraryInPrompt ~/ groups.length;
      return {
        for (final t in types)
          t: ranked.where((r) => fitsMeal(r, t)).take(perGroup).toList(),
      };
    }

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

    // Sveži ukusi pre zahteva ka AI-ju; odbijanje zaustavlja plan.
    Future<void> refreshTastes() async {
      final source = _tastes;
      if (source == null) return;
      try {
        tastes = await step(source.current);
      } on PlanGenerationFailed catch (e) {
        if (e.error is! PlanningTastesUnavailable) rethrow;
        tastes = PlanningTastes.none;
        draft = draft.copyWith(withoutTastes: true);
      }
      ranked = rankedFor(tastes);
    }

    // Sveža provera bezbednosti; bez nje (mreža, server) plan staje.
    Future<PlanSafety> checkSafety(Set<String> ids) async {
      final source = _safety;
      if (source == null) return const PlanSafety.unrestricted();
      return step(() => source.check(ids));
    }

    Future<void> refreshSafety() async {
      safety = await checkSafety({
        for (final r in eligible.take(maxSafetyRecipes)) r.id,
      });
      if (safety.restricted) {
        draft = draft.copyWith(householdRestricted: true);
      }
      ranked = rankedFor(tastes);
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
      await refreshTastes();
      await refreshSafety();
      final planned = {for (final p in draft.proposals.values) p.title};
      final candidates = candidatesFor({for (final s in slots) s.type});
      final offeredIds = {
        for (final list in candidates.values)
          for (final r in list) r.id,
      };
      // Ceo spisak jednom, po rangu; po obroku samo id-jevi.
      final offeredNow = [
        for (final r in ranked)
          if (offeredIds.contains(r.id)) r,
      ];
      final result = await step(
        () => _router.run(
          AIRequest(
            task: AITask.planOutline,
            system: mealPlanSystemPrompt,
            prompt: planOutlinePrompt(
              slots: slots,
              servings: request.servings,
              library: [
                for (final r in offeredNow)
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
              tastes: tastes,
              candidates: {
                for (final e in candidates.entries)
                  e.key: [for (final r in e.value) r.id],
              },
              allowNew: !safety.restricted,
            ),
            temperature: 0.8,
          ),
          (json) => parseOutline(
            json,
            slots: slots,
            library: {for (final r in offeredNow) r.id: r.title},
            allowed: {
              for (final e in candidates.entries)
                e.key: {for (final r in e.value) r.id},
            },
            allowNew: !safety.restricted,
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
        candidates: (type) => candidatesFor([type])[type]!,
        favorites: () => tastes.favoriteCounts.keys.toSet(),
      );
      if (!identical(before, draft.proposals)) onProgress?.call(draft);
    }

    // Završna provera na serveru, sa svežim podacima: recept izmenjen ili
    // alergija dodata usred pravljenja plana. Ono što ne prođe ostaje
    // prazno mesto.
    if (_safety != null && draft.proposals.isNotEmpty) {
      final ids = {for (final p in draft.proposals.values) ?p.libraryRecipeId};
      final last = await checkSafety(ids);
      if (last.restricted) {
        final kept = {
          for (final e in draft.proposals.entries)
            if (e.value.libraryRecipeId case final id? when last.allows(id))
              e.key: e.value,
        };
        draft = draft.copyWith(proposals: kept, householdRestricted: true);
        onProgress?.call(draft);
      }
    }

    final missingKeys = draft.missingRecipeKeys;
    if (missingKeys.isNotEmpty) await refreshTastes();
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
            prompt: recipeSummariesPrompt(batch, tastes: tastes),
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
    required List<Recipe> Function(MealType type) candidates,
    Set<String> Function()? favorites,
  }) async {
    Map<MealSlot, Set<MealRule>> breaksOf(Map<MealSlot, MealFacts> meals) =>
        mealRuleBreaks(
          meals,
          movable: movable,
          favorites: favorites?.call() ?? const {},
        );

    List<MealSlot> broken() {
      final breaks = breaksOf(facts());
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
    } on PlanGenerationFailed catch (e) {
      // Odbijen zahtev (drugo domaćinstvo, istekla prijava) zaustavlja plan;
      // ne nastavlja se sa podacima pročitanim pre odbijanja.
      if (e.error is PlanningTastesDenied) rethrow;
      // Inače novi predlog nije uspeo: ostaje prvi, pa ide rezervni korak.
    }

    bad = broken();
    for (final slot in bad) {
      final before = breaksOf(facts());
      for (final r in candidates(slot.type)) {
        final weight = r.labels.weightValue;
        if (weight == null) continue;
        final candidate = SlotProposal(
          title: r.title,
          libraryRecipeId: r.id,
          weight: weight,
          dishKind: r.labels.dishKindValue,
        );
        final after = breaksOf({...facts(), slot: candidate.facts});
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
/// za id recepta koji nije u [library] (id → naziv) i, kad je [allowed]
/// dat, za id koji nije na spisku baš tog obroka. Bez [allowNew] (neko u
/// domaćinstvu ima alergiju) novo jelo se ne prihvata: `recipeId: null`
/// znači da ništa ne odgovara, pa to mesto ostaje prazno.
Map<MealSlot, SlotProposal> parseOutline(
  Map<String, dynamic> json, {
  required List<MealSlot> slots,
  required Map<String, String> library,
  Map<MealType, Set<String>>? allowed,
  bool allowNew = true,
}) {
  final meals = json['meals'];
  if (meals is! List) throw const FormatException('Nema rasporeda');
  final wanted = slots.toSet();
  final result = <MealSlot, SlotProposal>{};
  final empty = <MealSlot>{};
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
    if (result.containsKey(slot) || empty.contains(slot)) {
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
      if (allowed != null && !(allowed[type]?.contains(id) ?? false)) {
        throw FormatException('Recept nije za taj obrok', '$slot');
      }
      result[slot] = SlotProposal(
        title: title,
        libraryRecipeId: id as String,
        weight: weight,
        dishKind: dishKind,
      );
      continue;
    }
    if (!allowNew) {
      empty.add(slot);
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
  if (result.length + empty.length != wanted.length) {
    throw const FormatException('Nedostaju mesta u rasporedu');
  }
  return result;
}

/// Čita detalje: tačno jedan recept za svaki od [titles], po
/// [draftRecipeKey]. Baca [FormatException] za višak, manjak, duplikat,
/// porcije van 1–20, neispravne sastojke ili korake (S1–S4).
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
    final key = draftRecipeKey(aiTitle(raw['title']));
    if (!wanted.containsKey(key)) {
      throw FormatException('Recept nije tražen', key);
    }
    if (result.containsKey(key)) {
      throw FormatException('Recept se ponavlja', key);
    }
    final steps = aiSteps(raw['steps']);
    if (steps.isEmpty) throw const FormatException('S4');
    result[key] = RecipeSnapshot(
      title: wanted[key]!,
      baseServings: aiServings(raw['servings'], max: maxServings, rule: 'S2'),
      prepMinutes: aiPrepMinutes(raw['prepMinutes']),
      ingredients: aiIngredients(raw['ingredients']),
      steps: steps,
    );
  }
  if (result.length != wanted.length) {
    throw const FormatException('Nedostaju recepti');
  }
  return result;
}
