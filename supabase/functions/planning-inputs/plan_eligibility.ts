// Bezbednost recepata za plan domaćinstva (spec 019 FR-104/105, TRELLO-43,
// ugovor 008 "Allergen protection"). Čista logika bez mreže: server joj daje
// redove recepata i namirnica, a ona kaže koji recepti smeju u plan.
//
// Pravilo: recept je bezbedan samo kad su SVI njegovi sastojci povezani sa
// aktivnom, pregledanom deljenom namirnicom i nijedna od njih nema alergen iz
// unije alergena članova. Nepoznato nikad nije bezbedno: nepovezan ili
// preimenovan sastojak, nepregledana, povučena ili kućna namirnica, prazan
// spisak sastojaka i neispravan zapis daju "nije bezbedno".

/** Grupe alergena iz EU Aneksa II, isti kodovi kao `AllergenGroup` u Dart-u. */
export const allergenCodes = new Set([
  "gluten",
  "crustaceans",
  "eggs",
  "fish",
  "peanuts",
  "soy",
  "milk",
  "nuts",
  "celery",
  "mustard",
  "sesame",
  "sulphites",
  "lupin",
  "molluscs",
]);

const linkSources = new Set(["matched", "confirmed"]);

/** Isto kao `ingredientKey` u `lib/domain/shopping_sync.dart`. */
export function ingredientKey(name: string): string {
  return name.trim().toLowerCase().replace(/\s+/g, " ");
}

export interface FoodRow {
  id: string;
  household_id: string | null;
  withdrawn_at: string | null;
  allergen_codes: string[] | null;
  allergen_reviewed_at: string | null;
}

export interface RecipeRow {
  id: string;
  ingredients: unknown;
}

/**
 * Id-jevi namirnica svih sastojaka, ili `null` kad ijedan sastojak nema
 * ispravnu vezu. Veza je zapisana ravno na sastojku (`foodId`, `matchedKey`,
 * `linkSource`) i važi samo dok je `matchedKey` jednak ključu naziva.
 */
export function recipeFoodIds(ingredients: unknown): string[] | null {
  if (!Array.isArray(ingredients) || ingredients.length === 0) return null;
  const ids: string[] = [];
  for (const raw of ingredients) {
    if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
      return null;
    }
    const item = raw as Record<string, unknown>;
    const { name, foodId, matchedKey, linkSource } = item;
    if (
      typeof name !== "string" || !name.trim() ||
      typeof foodId !== "string" || !foodId.trim() || foodId.length > 64 ||
      typeof matchedKey !== "string" ||
      typeof linkSource !== "string" || !linkSources.has(linkSource) ||
      matchedKey.trim() !== ingredientKey(name)
    ) {
      return null;
    }
    ids.push(foodId.trim());
  }
  return ids;
}

/**
 * Pregledane grupe alergena namirnice, ili `null` (nepoznato): nema je,
 * povučena je, kućna je (ne može imati pregled), nije pregledana ili ima
 * nepoznat kod.
 */
export function reviewedAllergens(
  food: FoodRow | undefined,
): Set<string> | null {
  if (
    !food || food.withdrawn_at !== null || food.household_id !== null ||
    food.allergen_codes === null || food.allergen_reviewed_at === null ||
    !Array.isArray(food.allergen_codes)
  ) {
    return null;
  }
  const groups = new Set<string>();
  for (const code of food.allergen_codes) {
    if (typeof code !== "string" || !allergenCodes.has(code)) return null;
    groups.add(code);
  }
  return groups;
}

/**
 * Da li recept sme u plan domaćinstva sa unijom alergena [union].
 * Prazna unija ne menja pravilo da sastojci moraju biti poznati; da li se
 * to pravilo uopšte primenjuje kad niko nema alergiju odlučuje pozivalac
 * (politika iz ugovora 008/019).
 */
export function isRecipeSafe(
  recipe: RecipeRow,
  foods: ReadonlyMap<string, FoodRow>,
  union: ReadonlySet<string>,
): boolean {
  const ids = recipeFoodIds(recipe.ingredients);
  if (ids === null) return false;
  for (const id of ids) {
    const groups = reviewedAllergens(foods.get(id));
    if (groups === null) return false;
    for (const group of groups) {
      if (union.has(group)) return false;
    }
  }
  return true;
}

/** Svi id-jevi namirnica koje treba pročitati za date recepte. */
export function foodIdsToRead(recipes: Iterable<RecipeRow>): string[] {
  const ids = new Set<string>();
  for (const recipe of recipes) {
    for (const id of recipeFoodIds(recipe.ingredients) ?? []) ids.add(id);
  }
  return [...ids].sort();
}

/** Unija alergena članova; nepoznat kod je greška (server ne pogađa). */
export function parseUnion(raw: unknown): Set<string> {
  if (!Array.isArray(raw)) throw new Error("plan_eligibility_union_shape");
  const union = new Set<string>();
  for (const code of raw) {
    if (typeof code !== "string" || !allergenCodes.has(code)) {
      throw new Error("plan_eligibility_union_shape");
    }
    union.add(code);
  }
  return union;
}
