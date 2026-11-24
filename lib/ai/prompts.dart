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
  "dishKind": one of ${jsonEncode([for (final k in DishKind.values) k.wire])},
  "image_description": string // in ENGLISH, see below
}
weight: light = small and easy (salad, yoghurt, toast); medium = a normal
meal; hearty = a filling main meal (pasulj, sarma, roast).
dishKind: soup = čorba or supa; cooked = stew or cooked dish (pasulj, gulaš,
sarma, rižoto); baked_fried = from the oven, grill or pan (musaka, piletina,
ćevapi, riba); pasta; salad; pie_pizza_sandwich = gibanica, pica, tost;
eggs_breakfast = kajgana, omlet, kaša; cold = spreads or a cold platter;
sweet = desserts and sweet dishes.
$imageDescriptionRules''';

/// Pravila za opis slike gotovog jela (TRELLO-130). Deli ih rezervni upit
/// kad AI recept nema opis ([imageDescriptionPrompt]).
const imageDescriptionRules = '''
image_description: 2-3 sentences in ENGLISH (about 50 words) describing only
what the finished dish looks like in a photo: its recognizable shape, colors,
the dish or vessel it is served in, a top-down view and any garnish. Always
state the distinctive shape explicitly, for example zeljanica = "one thick
rope of rolled phyllo coiled into a flat snail spiral, whole pie uncut, in a
round black pan, top-down"; sarma = "rolled cabbage leaf parcels in a pot of
reddish sauce". No text, people, hands, logos or brands.''';

/// Sistemski upit kad AI recept nema opis slike (jedan mali poziv).
const imageDescriptionSystemPrompt = '''
You describe finished home-cooked dishes for a food photographer.
Always answer with ONE JSON object and nothing else:
{"image_description": string}
$imageDescriptionRules''';

String imageDescriptionPrompt(Recipe recipe) =>
    '''
Describe how this finished dish looks.
${jsonEncode({
      'title': recipe.title,
      'ingredients': [for (final i in recipe.ingredients) i.name],
      'steps': recipe.steps,
    })}''';

/// Kako se piše naziv sastojka, da bi se povezao sa katalogom namirnica
/// (TRELLO-40, spec 018 FR-008). Deli se sa upitom za plan.
const ingredientNameRules = '''
Ingredient "name" is the food as you would buy it, in its basic dictionary
form (nominative singular, lowercase): "jaje", "crni luk", "paradajz",
"pileći file".
- No quantity, preparation, state, size or brand in "name"; put them in
  "note": "sitno iseckan crni luk" becomes name "crni luk" with note
  "sitno iseckan"; "2 velika jaja" becomes name "jaje", quantity 2, note
  "velika".
- One food per ingredient: "so i biber" is two ingredients, "so" and "biber".
- Name the kind when a shop sells several: "beli sir" or "mladi sir", not
  "sir"; ground paprika is "aleva paprika".
- A generic name, never a brand: "krem od lešnika", not "eurokrem".
- Keep words that make it a different food: "kiselo mleko", "mleveno meso",
  "beli luk", "mleko bez laktoze" and "pšenično brašno" stay as they are.''';

final recipeSystemPrompt =
    '''
You are the cooking assistant inside "Tavli", a recipe and shopping list app.
Always answer with ONE JSON object and nothing else.
All human-readable text must be in Serbian (Latin script).
Prefer metric units for new recipes. A quantity range such as "2-3" becomes
its middle (2.5), with the range in "note".
$ingredientNameRules
Recipe JSON schema:
$_recipeSchema''';

String recipeFromImagePrompt() => '''
Read the recipe from this image (printed, handwritten or a screenshot) and
return it in the recipe JSON schema. Keep the original quantities and write
each unit word as it appears (translated to Serbian if needed): "čaša" stays
"čaša", "dl" stays "dl"; do not convert units. If a single ingredient line
is unreadable, keep the recipe, write that ingredient with null quantity and
a best-guess name, and say in its "note" that it was unreadable. Never invent
quantities or ingredients you cannot see.
If the recipe does not state servings, estimate them. List every ingredient
the steps use. Copy only the steps that are written; if there are none, return
an empty list. Leave out greetings and wishes such as "Prijatno!".
If the image does not contain a recipe, or most of it is too blurred, cropped
or faint to read (no legible title and fewer than three legible ingredient
lines), return {"error": "not_a_recipe"} instead of guessing a recipe.''';

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
