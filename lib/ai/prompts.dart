import 'dart:convert';

import '../domain/recipe.dart';
import '../domain/recipe_labels.dart';
import 'ai_units.dart';

final _recipeSchema =
    '''
{
  "title": string,           // up to 120 characters
  "servings": integer,       // 1–99, always present
  "prepMinutes": integer | null,
  "ingredients": [           // 1–60, every ingredient used in the steps
    {
      "name": string,            // osnovni naziv, npr. "crni luk", bez količine
      "quantity": number | null, // a number > 0, npr. 0.5 (never text like "1/2"); null za "po ukusu"
      "unit": string | null,     // e.g. $aiUnitList
      "category": one of ${jsonEncode(ingredientCategories)},
      "note": string | null      // npr. "sitno iseckan", up to 200 characters
    }
  ],
  "steps": [string],         // preparation only, no numbering, no greetings
  "meals": [one of ${jsonEncode([for (final m in MealSuitability.values) m.wire])}],
                             // meals the dish suits, one or more
  "weight": one of ${jsonEncode([for (final w in DishWeight.values) w.wire])},
  "dishKind": one of ${jsonEncode([for (final k in DishKind.values) k.wire])}
}
weight: light = small and easy (salad, yoghurt, toast); medium = a normal
meal; hearty = a filling main meal (pasulj, sarma, roast).
dishKind: soup = čorba or supa; cooked = stew or cooked dish (pasulj, gulaš,
sarma, rižoto); baked_fried = from the oven, grill or pan (musaka, piletina,
ćevapi, riba); pasta; salad; pie_pizza_sandwich = gibanica, pica, tost;
eggs_breakfast = kajgana, omlet, kaša; cold = spreads or a cold platter;
sweet = desserts and sweet dishes.''';

final recipeSystemPrompt = '''
You are the cooking assistant inside "Tavli", a recipe and shopping list app.
Always answer with ONE JSON object and nothing else.
All human-readable text must be in Serbian (Latin script).
Prefer metric units for new recipes. Ingredient names are lowercase base names
without quantities. A quantity range such as "2-3" becomes its middle (2.5),
with the range in "note".
Recipe JSON schema:
$_recipeSchema''';

String recipeFromImagePrompt() => '''
Read the recipe from this image (printed, handwritten or a screenshot) and
return it in the recipe JSON schema. Keep the original quantities and write
each unit word as it appears (translated to Serbian if needed): "čaša" stays
"čaša", "dl" stays "dl"; do not convert units. If something is unreadable,
make a sensible guess and mention it in that ingredient's "note".
If the recipe does not state servings, estimate them. List every ingredient
the steps use. Copy only the steps that are written; if there are none, return
an empty list. Leave out greetings and wishes such as "Prijatno!".
If the image does not contain a recipe, return {"error": "not_a_recipe"}.''';

String recipeFromNamePrompt(
  String dishName, {
  required int servings,
  String? notes,
}) =>
    '''
Create a home-cooking recipe for: "$dishName".
Servings: $servings.
${notes == null || notes.isEmpty ? '' : 'Extra wishes: $notes\n'}Use ingredients that are easy to find in Serbian supermarkets.
Return it in the recipe JSON schema.''';

String refineRecipePrompt(Recipe current, String instruction) =>
    '''
Here is the current recipe:
${jsonEncode(current.toAiJson())}

Change it according to this request: "$instruction"
Keep everything that the request does not affect.
Return the whole updated recipe in the recipe JSON schema.''';
