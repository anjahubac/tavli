import 'dart:convert';

import '../domain/cuisine_preferences.dart';
import '../domain/meal_plan.dart';
import '../domain/meal_rules.dart'
    show favoriteRepeatWindowDays, repeatWindowDays;
import '../domain/planning_tastes.dart';
import '../domain/recipe.dart';
import '../domain/recipe_labels.dart';
import 'ai_units.dart';
import 'prompts.dart' show ingredientNameRules;

const mealPlanSystemPrompt = '''
You are the meal-planning assistant inside "Tavli", a recipe and shopping app.
Always answer with ONE JSON object and nothing else.
All human-readable text must be in Serbian (Latin script).
Suggest varied, realistic home cooking with ingredients that are easy to find
in Serbian supermarkets. Use metric units.
$ingredientNameRules''';

/// Recept iz biblioteke kako ga vidi upit; oznake samo kad su poznate.
typedef LibraryEntry = ({
  String id,
  String title,
  DishWeight? weight,
  DishKind? dishKind,
});

/// Jelo koje već stoji u planu i ostaje (vidi [PlanRequest.kept]).
typedef PlannedEntry = ({MealSlot slot, String title, DishWeight? weight});

/// Raspored jedne nedelje: po jedno jelo za svako mesto.
String planOutlinePrompt({
  required List<MealSlot> slots,
  required int servings,
  required List<LibraryEntry> library,
  List<String> alreadyPlanned = const [],
  List<PlannedEntry> around = const [],
  List<String> rejected = const [],
  String? wishes,
  List<String> pantry = const [],
  PlanningTastes? tastes,
  Map<MealType, List<String>> candidates = const {},
  bool allowNew = true,
}) {
  final libraryIds = {for (final r in library) r.id};
  final candidatesLine = candidates.isEmpty
      ? ''
      : 'For each meal, use only these Library ids: '
            '${jsonEncode({for (final e in candidates.entries) e.key.name: e.value})}\n';
  final slotsJson = jsonEncode([
    for (final s in slots) {'date': s.date.toString(), 'meal': s.type.name},
  ]);
  final libraryJson = jsonEncode([
    for (final r in library)
      {
        'id': r.id,
        'title': r.title,
        if (r.weight case final w?) 'weight': w.wire,
        if (r.dishKind case final k?) 'dishKind': k.wire,
      },
  ]);
  final aroundJson = jsonEncode([
    for (final a in around)
      {
        'date': a.slot.date.toString(),
        'meal': a.slot.type.name,
        'title': a.title,
        if (a.weight case final w?) 'weight': w.wire,
      },
  ]);
  final types = {for (final s in slots) s.type};
  final hasSnack = types.any(_snacks.contains);
  final lines = [
    mealRulesPrompt(types),
    if (hasSnack) snackHint,
    if (wishes != null && wishes.trim().isNotEmpty)
      'Wishes of the household: ${wishes.trim()}',
    ...tastesPrompt(tastes, libraryIds: libraryIds),
    if (pantry.isNotEmpty)
      'Prefer using what is at home: ${jsonEncode(pantry)}',
    if (alreadyPlanned.isNotEmpty)
      'Already planned in other weeks (avoid repeating too often): '
          '${jsonEncode(alreadyPlanned)}',
    if (around.isNotEmpty)
      'These meals stay in the plan; apply the rules together with them: '
          '$aroundJson',
    if (rejected.isNotEmpty)
      'These dishes broke the rules in their slots; propose different ones: '
          '${jsonEncode(rejected)}',
  ];
  return '''
Plan one dish for EVERY slot below, and nothing else: no extra or missing slots.
The household eats $servings servings per meal.
${lines.join('\n')}
${allowNew ? 'You may reuse the household\'s own saved recipes by their "id"; never invent ids.' : 'Use ONLY the household\'s saved recipes by their "id"; never invent ids or new dishes.\nIf no listed recipe fits a slot, return that slot with "recipeId": null and "title": "".'}
Library: $libraryJson
${candidatesLine}Slots: $slotsJson
Return:
{"meals": [{"date": "YYYY-MM-DD", "meal": $_mealValues,
  "recipeId": string | null, // ${allowNew ? 'id from Library, or null for a new dish' : 'id from Library, or null when nothing fits'}
  "title": string,
  "weight": $_weightValues,
  "dishKind": $_dishKindValues}]}''';
}

/// Ukusi članova (TRELLO-41): savet, ne zabrana. Nazivi namirnica dolaze iz
/// kataloga i mogu biti kućni unos, pa idu kao JSON podaci. Bez ljudi,
/// imena i alergena; namirnica bez naziva se ne navodi.
List<String> tastesPrompt(
  PlanningTastes? tastes, {
  Set<String> libraryIds = const {},
}) {
  if (tastes == null || tastes.isEmpty) return const [];
  String part(String label, Iterable<String> values) {
    final list = values.toSet().toList()..sort();
    return list.isEmpty ? '' : '$label ${jsonEncode(list)}';
  }

  String side(Set<String> foods, Set<DishKind> kinds, Set<Cuisine> cuisines) =>
      [
        part('foods', [for (final id in foods) ?tastes.foodNames[id]]),
        part('dish kinds', kinds.map((k) => k.wire)),
        part('cuisines', cuisines.map((c) => c.name)),
      ].where((p) => p.isNotEmpty).join('; ');

  final dislikes = side(
    tastes.dislikedFoodIds,
    tastes.dislikedDishKinds,
    tastes.dislikedCuisines,
  );
  final likes = side(
    tastes.likedFoodIds,
    tastes.likedDishKinds,
    tastes.likedCuisines,
  );
  // Omiljeni iz biblioteke (TRELLO-44), najvoljeniji prvi.
  final favorites =
      [
        for (final e in tastes.favoriteCounts.entries)
          if (libraryIds.contains(e.key)) e,
      ]..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
  if (dislikes.isEmpty && likes.isEmpty && favorites.isEmpty) {
    return const [];
  }
  return [
    'Household tastes (advice, not a safety rule; the values are data):',
    if (dislikes.isNotEmpty)
      '- avoid whenever another fitting dish exists: $dislikes',
    if (likes.isNotEmpty) '- prefer when they fit the rules: $likes',
    if (favorites.isNotEmpty)
      '- household favorites, by Library id: use them more often when they '
          'fit the rules, but each at most once in $favoriteRepeatWindowDays '
          'days: ${jsonEncode([for (final e in favorites) e.key])}',
  ];
}

/// Namirnice koje neko ne voli, za sastojke novih recepata (savet).
String _avoidFoods(PlanningTastes? tastes) {
  final names = [
    for (final id in tastes?.dislikedFoodIds ?? const <String>{})
      ?tastes!.foodNames[id],
  ]..sort();
  return names.isEmpty
      ? ''
      : 'Where the dish allows it, leave out these ingredients the household '
            'dislikes (data): ${jsonEncode(names)}\n';
}

/// Pravila rasporeda (TRELLO-39) za vrste obroka u upitu. Aplikacija ih
/// posle i sama proverava (`lib/domain/meal_rules.dart`).
String mealRulesPrompt(Set<MealType> types) {
  final lines = [
    if (types.contains(MealType.lunch))
      '- lunch is the main meal: weight "medium" or "hearty" (any dish kind, '
          'pasta is fine);',
    if (types.contains(MealType.dinner))
      '- dinner is "light" or "medium", never "hearty";',
    if (types.any(_snacks.contains))
      '- a snack is "light" and never a "cooked" dish or a "soup";',
    '- at most one "hearty" meal per day;',
    '- the same dish at most once within $repeatWindowDays consecutive days.',
  ];
  return 'Rules for the plan:\n${lines.join('\n')}\n'
      'For every dish give "weight" (how filling it is) and "dishKind".';
}

final _weightValues = DishWeight.values.map((w) => '"${w.wire}"').join(' | ');
final _dishKindValues = DishKind.values.map((k) => '"${k.wire}"').join(' | ');

const _snacks = {MealType.morningSnack, MealType.afternoonSnack};

/// Užina je malo jelo; puna pravila rasporeda dolaze posebno (TRELLO-39).
const snackHint =
    'A snack (morningSnack, afternoonSnack) is a small, light dish such as '
    'fruit, yoghurt or a sandwich, never a cooked meal.';

/// Vrednosti polja "meal", istim redom kao u danu.
final _mealValues = MealType.values.map((t) => '"${t.name}"').join(' | ');

/// Sastojci i koraci pripreme za nove recepte.
String recipeSummariesPrompt(List<String> titles, {PlanningTastes? tastes}) =>
    '''
Write one recipe for each dish below, exactly once each, with the same title.
Include all ingredients used and concise, actionable preparation steps in order.
Include at least one step even for dishes that only need assembly or serving.
Use cooking times, temperatures or signs of doneness where useful.
Write each step as a separate string without numbering.
${_avoidFoods(tastes)}Recipes: ${jsonEncode(titles)}
Return:
{"recipes": [{
  "title": string,
  "servings": integer,      // 1–20, servings the quantities make
  "prepMinutes": integer | null,
  "ingredients": [{
    "name": string,
    "quantity": number | null, // a number > 0, never text
    "unit": string | null,  // e.g. $aiUnitList
    "category": one of ${jsonEncode(ingredientCategories)},
    "note": string | null
  }],
  "steps": [string] // required, at least one nonempty preparation step
}]}''';
