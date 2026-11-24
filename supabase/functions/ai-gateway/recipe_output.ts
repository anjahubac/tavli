// Server-side structural check of `recipe.v1` (spec 014 contract, R1, R2, R4,
// R5, R10, R11) for `recipe_from_image`. The client still applies the full
// validation; this only stops an obviously wrong answer from leaving the
// gateway as a successful 200. Quantities, units and categories stay with the
// client. Extraction mirrors the client (`lib/ai/ai_router.dart`): the object
// between the first `{` and the last `}`, so a fenced answer is still read.
import { record } from "./input.ts";

function jsonObject(text: string): Record<string, unknown> | undefined {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end < start) return;
  try {
    return record(JSON.parse(text.slice(start, end + 1)));
  } catch {
    return;
  }
}

function text(value: unknown, max: number): boolean {
  if (typeof value !== "string") return false;
  const length = value.trim().length;
  return length >= 1 && length <= max;
}

export function validRecipeOutput(content: string): boolean {
  const recipe = jsonObject(content);
  if (!recipe) return false;
  if (recipe.error === "not_a_recipe") return true;
  const { title, servings, ingredients, steps } = recipe;
  if (!text(title, 120)) return false;
  if (
    typeof servings !== "number" || !Number.isInteger(servings) ||
    servings < 1 || servings > 99
  ) return false;
  if (
    !Array.isArray(ingredients) || ingredients.length < 1 ||
    ingredients.length > 60
  ) return false;
  for (const item of ingredients) {
    if (!text(record(item)?.name, 80)) return false;
  }
  if (steps === undefined || steps === null) return true;
  return Array.isArray(steps) && steps.length <= 40 &&
    steps.every((step) => typeof step === "string" && step.length <= 1000);
}
