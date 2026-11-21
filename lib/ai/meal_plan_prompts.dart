import 'dart:convert';

import '../domain/meal_plan.dart';
import '../domain/meal_rules.dart' show repeatWindowDays;
import '../domain/recipe.dart';
import '../domain/recipe_labels.dart';
import 'ai_units.dart';

const mealPlanSystemPrompt = '''
You are the meal-planning assistant inside "Tavli", a recipe and shopping app.
Always answer with ONE JSON object and nothing else.
All human-readable text must be in Serbian (Latin script).
Suggest varied, realistic home cooking with ingredients that are easy to find
in Serbian supermarkets. Use metric units. Ingredient names are lowercase base
names without quantities.''';

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
}) {
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
You may reuse the household's own saved recipes by their "id"; never invent ids.
Library: $libraryJson
Slots: $slotsJson
Return:
{"meals": [{"date": "YYYY-MM-DD", "meal": $_mealValues,
  "recipeId": string | null, // id from Library, or null for a new dish
  "title": string,
  "weight": $_weightValues,
  "dishKind": $_dishKindValues}]}''';
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

/// Sažeci novih recepata (naziv i sastojci, bez koraka).
String recipeSummariesPrompt(List<String> titles) =>
    '''
Write a short recipe summary for each dish below, exactly once each, with the
same title. No preparation steps.
Recipes: ${jsonEncode(titles)}
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
  }]
}]}''';
