import {
  foodIdsToRead,
  type FoodRow,
  ingredientKey,
  isRecipeSafe,
  parseUnion,
  recipeFoodIds,
  reviewedAllergens,
} from "./plan_eligibility.ts";
import fixture from "./testdata/ingredient_keys.json" with { type: "json" };

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      "Actual: " + JSON.stringify(actual) + "; expected: " +
        JSON.stringify(expected),
    );
  }
}

const reviewed = "2026-11-24T00:00:00Z";

function food(
  id: string,
  codes: string[] | null,
  extra: Partial<FoodRow> = {},
): FoodRow {
  return {
    id,
    household_id: null,
    withdrawn_at: null,
    allergen_codes: codes,
    allergen_reviewed_at: codes === null ? null : reviewed,
    ...extra,
  };
}

/** Sastojak sa vezom, u obliku u kom ga aplikacija čuva (ravna polja). */
function linked(
  name: string,
  foodId: string,
  source = "matched",
  matchedKey = ingredientKey(name),
) {
  return {
    name,
    quantity: 1,
    unit: "kom",
    foodId,
    matchedKey,
    linkSource: source,
  };
}

const foods = new Map<string, FoodRow>([
  ["flour", food("flour", ["gluten"])],
  ["egg", food("egg", ["eggs"])],
  ["salt", food("salt", [])],
  ["peanut", food("peanut", ["peanuts"])],
  ["unknown", food("unknown", null)],
  ["withdrawn", food("withdrawn", [], { withdrawn_at: reviewed })],
  ["house", food("house", null, { household_id: "h1" })],
]);

Deno.test("ingredientKey matches the shared Dart fixture", () => {
  for (
    const [input, expected]
      of (fixture as unknown as { cases: [string, string][] }).cases
  ) {
    equal(ingredientKey(input), expected);
  }
});

Deno.test("a fully linked, reviewed recipe without the household's allergens is safe", () => {
  const recipe = {
    id: "palacinke",
    ingredients: [
      linked("Brašno", "flour"),
      linked("jaja", "egg"),
      linked("so", "salt", "confirmed"),
    ],
  };
  equal(isRecipeSafe(recipe, foods, new Set()), true);
  equal(isRecipeSafe(recipe, foods, new Set(["peanuts"])), true);
  equal(isRecipeSafe(recipe, foods, new Set(["gluten"])), false);
  equal(isRecipeSafe(recipe, foods, new Set(["eggs", "milk"])), false);
});

Deno.test("unknown is never safe", () => {
  const cases: unknown[] = [
    [], // bez sastojaka
    null,
    "not a list",
    [{ name: "so", quantity: 1 }], // bez veze
    [linked("Crni luk", "salt", "matched", "beli luk")], // preimenovan
    [linked("so", "salt", "suggested")], // nepoznat izvor
    [{ ...linked("so", "salt"), foodId: "" }],
    [{ ...linked("so", "salt"), foodId: "x".repeat(65) }],
    [linked("misterija", "missing")], // namirnica ne postoji
    [linked("x", "unknown")], // nepregledana
    [linked("x", "withdrawn")], // povučena
    [linked("x", "house")], // kućna
    ["so"],
  ];
  for (const ingredients of cases) {
    equal(isRecipeSafe({ id: "r", ingredients }, foods, new Set()), false);
  }
});

Deno.test("one unlinked staple makes the whole recipe ineligible", () => {
  const recipe = {
    id: "r",
    ingredients: [linked("Brašno", "flour"), { name: "voda", quantity: 1 }],
  };
  equal(isRecipeSafe(recipe, foods, new Set()), false);
});

Deno.test("reviewed allergens fail closed on an unknown code", () => {
  equal(reviewedAllergens(food("x", ["milk", "unicorn"])), null);
  equal([...reviewedAllergens(food("x", ["milk"]))!], ["milk"]);
  equal(reviewedAllergens(food("x", [])) !== null, true);
  equal(reviewedAllergens(undefined), null);
});

Deno.test("recipe food ids keep order; foods to read are unique and sorted", () => {
  equal(
    recipeFoodIds([linked("jaja", "egg"), linked("Brašno", "flour")]),
    ["egg", "flour"],
  );
  equal(
    foodIdsToRead([
      {
        id: "a",
        ingredients: [linked("jaja", "egg"), linked("Brašno", "flour")],
      },
      { id: "b", ingredients: [linked("jaja", "egg")] },
      { id: "c", ingredients: [{ name: "voda" }] },
    ]),
    ["egg", "flour"],
  );
});

Deno.test("the union accepts only known codes", () => {
  equal([...parseUnion(["peanuts", "milk"])].sort(), ["milk", "peanuts"]);
  equal(parseUnion([]).size, 0);
  for (const bad of [null, "peanuts", ["peanuts", 1], ["kikiriki"]]) {
    let threw = false;
    try {
      parseUnion(bad);
    } catch {
      threw = true;
    }
    equal(threw, true);
  }
});
