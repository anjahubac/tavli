/// Pravila rasporeda obroka (spec 019 FR-102/FR-103, TRELLO-39).
///
/// Proverava se u aplikaciji, ne samo u upitu: AI ume da pogreši, pa
/// `MealPlanAI` posle odgovora proveri plan i popravi mesta koja ne
/// prolaze. Nepoznata oznaka (`null`) nije greška: to jelo se po tom
/// pravilu ne proverava.
library;

import 'meal_plan.dart';
import 'recipe_labels.dart';

/// Isti recept se ne ponavlja u ovoliko uzastopnih dana.
const repeatWindowDays = 3;

/// Šta pravila znaju o jelu na jednom mestu.
class MealFacts {
  const MealFacts({
    required this.recipeKey,
    this.title,
    this.weight,
    this.dishKind,
  });

  /// Isti ključ = isti recept: id iz biblioteke ili [draftRecipeKey].
  final String recipeKey;

  /// Naziv za upit (jela koja ostaju u planu); pravila ga ne gledaju.
  final String? title;
  final DishWeight? weight;
  final DishKind? dishKind;

  @override
  bool operator ==(Object other) =>
      other is MealFacts &&
      other.recipeKey == recipeKey &&
      other.title == title &&
      other.weight == weight &&
      other.dishKind == dishKind;

  @override
  int get hashCode => Object.hash(recipeKey, title, weight, dishKind);

  @override
  String toString() => 'MealFacts($recipeKey, $weight, $dishKind)';
}

enum MealRule {
  /// Ručak je glavni obrok: srednji ili jak.
  lunchTooLight,

  /// Večera je lagana ili srednja.
  dinnerTooHeavy,

  /// Užina je lagana.
  snackNotLight,

  /// Užina nije kuvano jelo ni čorba.
  snackCooked,

  /// Najviše jedan jak obrok dnevno.
  secondHearty,

  /// Isti recept ne ide dva puta u [repeatWindowDays] dana.
  repeated,
}

const _snacks = {MealType.morningSnack, MealType.afternoonSnack};

/// Pravila koja zavise samo od jela i mesta (bez ostatka plana).
Set<MealRule> slotRuleBreaks(MealType type, MealFacts facts) => {
  if (type == MealType.lunch && facts.weight == DishWeight.light)
    MealRule.lunchTooLight,
  if (type == MealType.dinner && facts.weight == DishWeight.hearty)
    MealRule.dinnerTooHeavy,
  if (_snacks.contains(type) &&
      facts.weight != null &&
      facts.weight != DishWeight.light)
    MealRule.snackNotLight,
  if (_snacks.contains(type) &&
      (facts.dishKind == DishKind.cooked || facts.dishKind == DishKind.soup))
    MealRule.snackCooked,
};

/// Prekršena pravila po mestu, za ceo [meals] (predlozi i jela koja
/// ostaju). Kod dva jaka obroka u danu krši pravilo onaj koji nije ručak;
/// kod ponovljenog recepta kasnije mesto.
Map<MealSlot, Set<MealRule>> mealRuleBreaks(Map<MealSlot, MealFacts> meals) {
  final result = <MealSlot, Set<MealRule>>{};
  void add(MealSlot s, MealRule r) => (result[s] ??= {}).add(r);

  for (final e in meals.entries) {
    for (final r in slotRuleBreaks(e.key.type, e.value)) {
      add(e.key, r);
    }
  }

  final slots = meals.keys.toList()..sort();
  final heartyByDay = <Object, List<MealSlot>>{};
  for (final s in slots) {
    if (meals[s]!.weight == DishWeight.hearty) {
      (heartyByDay[s.date] ??= []).add(s);
    }
  }
  for (final day in heartyByDay.values) {
    if (day.length < 2) continue;
    final keep = day.firstWhere(
      (s) => s.type == MealType.lunch,
      orElse: () => day.first,
    );
    for (final s in day) {
      if (s != keep) add(s, MealRule.secondHearty);
    }
  }

  for (var i = 0; i < slots.length; i++) {
    for (var j = 0; j < i; j++) {
      final a = slots[j], b = slots[i];
      if (meals[a]!.recipeKey == meals[b]!.recipeKey &&
          a.date.daysUntil(b.date) < repeatWindowDays) {
        add(b, MealRule.repeated);
        break;
      }
    }
  }
  return result;
}

/// Parovi ručak/večera istog dana koje treba zameniti: oba mesta smeju da
/// se menjaju ([movable]), bar jedno krši pravilo težine, a posle zamene
/// nijedno ne krši pravila mesta.
List<(MealSlot, MealSlot)> lunchDinnerSwaps(
  Map<MealSlot, MealFacts> meals,
  Set<MealSlot> movable,
) {
  final swaps = <(MealSlot, MealSlot)>[];
  for (final lunch in movable) {
    if (lunch.type != MealType.lunch) continue;
    final dinner = MealSlot(lunch.date, MealType.dinner);
    if (!movable.contains(dinner)) continue;
    final l = meals[lunch], d = meals[dinner];
    if (l == null || d == null) continue;
    final broken =
        slotRuleBreaks(MealType.lunch, l).isNotEmpty ||
        slotRuleBreaks(MealType.dinner, d).isNotEmpty;
    final fixed =
        slotRuleBreaks(MealType.lunch, d).isEmpty &&
        slotRuleBreaks(MealType.dinner, l).isEmpty;
    if (broken && fixed) swaps.add((lunch, dinner));
  }
  return swaps;
}

/// Jela iz sačuvanog plana koja ostaju, kao činjenice za pravila. Oznake
/// se uzimaju iz recepta u biblioteci ([labelsById]); jelo bez recepta
/// ima ključ po nazivu i nepoznate oznake.
Map<MealSlot, MealFacts> plannedMealFacts(
  Iterable<PlannedMeal> meals,
  Map<String, RecipeLabels> labelsById,
) => {
  for (final m in meals)
    if (m.snapshot != null || m.recipeId != null)
      m.slot: MealFacts(
        recipeKey: m.recipeId ?? draftRecipeKey(m.snapshot!.title),
        title: m.snapshot?.title,
        weight: labelsById[m.recipeId]?.weightValue,
        dishKind: labelsById[m.recipeId]?.dishKindValue,
      ),
};
