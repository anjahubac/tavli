# Contract: catalog-ready ingredient names from AI

**Status**: implemented on `feat/ai-catalog-ingredients` (Trello TRELLO-40,
spec 018 FR-008, D2-008), pending review.
**Author**: Dev 2 | **Reviewer**: Dev 1 (catalog matcher consumer)
**Date**: 2026-11-21 | **Builds on**:
[ingredient model](../ingredient-model-proposal.md), the alias matcher
(`lib/domain/food_matcher.dart`, D1-007)

## Problem

The alias matcher links an ingredient only when `ingredientKey(name)` equals a
catalog name or alias exactly. A name such as “sitno iseckan crni luk” or
“so i biber” never matches, even though the food is in the catalog.

## What the AI returns

The recipe and plan prompts share `ingredientNameRules`
(`lib/ai/prompts.dart`):

| Rule | Example |
| --- | --- |
| `name` is the food as bought, basic dictionary form (nominative singular, lowercase) | “jaje”, “crni luk”, “pileći file” |
| Quantity, preparation, state, size and brand go to `note` | “sitno iseckan crni luk” → name “crni luk”, note “sitno iseckan” |
| One food per ingredient | “so i biber” → “so” and “biber” |
| Words that make a different food stay | “kiselo mleko”, “mleveno meso”, “beli luk” |

The JSON shape is unchanged. Plural or inflected forms (“jaja”, “crnog
luka”) are covered by catalog aliases, not by the prompt.

## No rewriting in the app

The app does not rewrite AI names. A first version moved a trailing
parenthesis to the note, but “mleko (bez laktoze)” then became “mleko” and
matched plain milk, and it also became the shopping merge key (Dev 1 review).
Code cannot tell preparation from a product variant, so the name stays as the
AI wrote it and the prompt carries the rules.

## Consumers

| Consumer | Effect |
| --- | --- |
| Alias matcher, future link writer (D1-008) | more exact matches |
| Shopping merge by `ingredientKey` | more items merge (same base name) |
| Stored recipes | only new AI answers change; saved recipes are not rewritten |

## Measurement

Local script (`dev/measure_catalog_names.dart`, not committed) runs 30 dish
names through `RecipeAI.fromDishName` with built-in keys and checks every
ingredient name with `AliasFoodMatcher` against
[legacy-food-reference.csv](../research/legacy-food-reference.csv) (171 foods
with aliases; not the accepted catalog). Measured 2026-11-21 with the built-in
free Gemini key only (Pro was out of daily quota, so Flash and Flash-Lite
answered):

| Run | Prompt | Matched |
| --- | --- | --- |
| 1 | base-name, note and one-food rules | 230/264 (87.1%) |
| 2 | plus “name the kind” and “no brand” | 244/269 (90.7%) |

Run 1 misses: 11 name errors (“sir” instead of “beli sir”, “crvena mlevena
paprika” instead of “aleva paprika”, a brand, a typo), 9 missing aliases, 14
foods absent from the list. The two rules added for run 2 remove the first
group. Run 2 misses (25) are almost all catalog gaps, reported to Dev 1:

| Gap | Names from the AI |
| --- | --- |
| Food absent | svinjski but, svinjski file, svinjska mast, suva rebra, teleće meso, feta sir, brancin, crveni luk, paškanat, žumance, pileća supa, paradajz sos |
| Alias absent | kore za gibanicu → kore za pitu, špageti → špagete, paradajz pelat → pelat, suva slanina → slanina, koren peršuna → peršun, suvi biljni začin → začinska mešavina, krem od lešnika |

Remaining name errors: “bela vino” (typo) and “pileći batak sa karabatakom”.
The result depends on the model; it is measured again with the paid model
(015 D3) and the accepted catalog.

The card's acceptance (90% of ingredients from 30 recipes link without manual
fixes) is measured again against the accepted catalog (TRELLO-19). Names that
miss because the food or alias is absent are reported to Dev 1 as catalog
gaps, not prompt errors.

## Evidence

- `test/ai/ai_response_validator_test.dart`, group *naziv sastojka za
  katalog*: a variant name such as “mleko (bez laktoze)” stays unchanged;
  both prompts carry the rules.
