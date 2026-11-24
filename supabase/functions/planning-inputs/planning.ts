// Ukusi članova za plan obroka (spec 019 FR-004, ugovor 008).
//
// Server sam određuje domaćinstvo i učesnike (svi trenutni članovi), daje
// listu vidljivih namirnica i poziva `planning_advisory_inputs` sa
// `for_provider = true`: doprinose samo članovi koji su uključili deljenje
// za planiranje, i za sopstvene podatke, jer rezultat ide AI-ju. Odgovor ima
// šest nizova ukusa i broj članova po omiljenom receptu (TRELLO-44): bez
// članova, imena i alergena.
//
// Isti endpoint uz `recipeIds` proverava bezbednost recepata za plan
// (spec 019 FR-104/105, ugovor 008 "Allergen protection", TRELLO-43): server
// čita uniju alergena svih članova i kaže samo koji od datih recepata smeju
// u plan. Alergeni i članovi nikad ne idu u odgovor.
// Ništa se ne kešira i ne loguje.

import {
  foodIdsToRead,
  type FoodRow,
  isRecipeSafe,
  parseUnion,
  type RecipeRow,
} from "./plan_eligibility.ts";

export const tasteKeys = [
  "likedFoodIds",
  "dislikedFoodIds",
  "likedDishKinds",
  "dislikedDishKinds",
  "likedCuisineCodes",
  "dislikedCuisineCodes",
] as const;

export type Tastes = Record<(typeof tasteKeys)[number], string[]> & {
  favoriteRecipeCounts: Record<string, number>;
};

export interface AdvisoryRequest {
  actor: string;
  household: string;
  participants: string[];
  visibleFoodIds: string[];
}

export interface PlanningDependencies {
  /** Id prijavljenog (ne anonimnog) korisnika ili null. */
  authenticate(token: string): Promise<string | null>;
  /** Domaćinstvo korisnika (najviše jedno) ili null. */
  householdOf(uid: string): Promise<string | null>;
  membersOf(household: string): Promise<string[]>;
  /** Namirnice iz ukusa [participants] koje [household] sme da vidi. */
  visibleTasteFoods(household: string, participants: string[]): Promise<
    string[]
  >;
  advisory(request: AdvisoryRequest): Promise<unknown>;
  /** Unija alergena [participants] (RPC `planning_allergen_codes`). */
  allergenUnion(request: Omit<AdvisoryRequest, "visibleFoodIds">): Promise<
    unknown
  >;
  /** Recepti [household] sa datim id-jevima (ostali se ne vraćaju). */
  recipes(household: string, ids: string[]): Promise<RecipeRow[]>;
  /** Namirnice sa datim id-jevima, sa pregledom alergena. */
  foods(ids: string[]): Promise<FoodRow[]>;
  /** Ograničenje zahteva po korisniku; false znači 429. */
  allow(uid: string): boolean;
}

const maxBodyBytes = 80_000;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const maxItems = 500;

/** Najviše recepata u jednoj proveri bezbednosti. */
export const maxRecipeIds = 1000;
const recipeId = /^[A-Za-z0-9_-]{1,64}$/;

export interface PlanningRequest {
  household: string;
  /** Recepti za proveru bezbednosti; bez njih zahtev traži ukuse. */
  recipeIds?: string[];
}

const headers = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};

function respond(status: number, body: unknown, extra?: HeadersInit) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, ...extra },
  });
}

const failure = (status: number, error: string) => respond(status, { error });

/**
 * Čita `{"householdId": uuid}` (ukusi) ili `{"householdId": uuid,
 * "recipeIds": [...]}` (bezbednost); sve ostalo je nevažeće. Id recepta
 * koji nije u dozvoljenom obliku se izostavlja: nije poznat, pa nije ni
 * bezbedan.
 */
export async function parseRequest(
  request: Request,
): Promise<PlanningRequest | null> {
  if (Number(request.headers.get("Content-Length")) > maxBodyBytes) return null;
  const text = await request.text();
  if (new TextEncoder().encode(text).length > maxBodyBytes) return null;
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    return null;
  }
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return null;
  }
  const keys = Object.keys(body);
  const { householdId: id, recipeIds } = body as Record<string, unknown>;
  if (typeof id !== "string" || !uuid.test(id)) return null;
  if (keys.length === 1) return { household: id };
  if (
    keys.length !== 2 || !Array.isArray(recipeIds) ||
    recipeIds.length > maxRecipeIds ||
    !recipeIds.every((r) => typeof r === "string")
  ) {
    return null;
  }
  return {
    household: id,
    recipeIds: [...new Set(recipeIds as string[])].filter((r) =>
      recipeId.test(r)
    ).sort(),
  };
}

/**
 * Bezbednost recepata za plan. Bez alergena u domaćinstvu plan je kao
 * ranije (`restricted: false`). Inače samo recepti čiji su svi sastojci
 * povezani sa pregledanim namirnicama bez alergena iz unije.
 */
export async function planSafety(
  deps: PlanningDependencies,
  request: Omit<AdvisoryRequest, "visibleFoodIds">,
  recipeIds: string[],
): Promise<{ restricted: boolean; safeRecipeIds?: string[] }> {
  const union = parseUnion(await deps.allergenUnion(request));
  if (union.size === 0) return { restricted: false };
  const recipes = recipeIds.length === 0
    ? []
    : await deps.recipes(request.household, recipeIds);
  const foodIds = foodIdsToRead(recipes);
  const foods = new Map(
    (foodIds.length === 0 ? [] : await deps.foods(foodIds)).map((
      f,
    ) => [f.id, f]),
  );
  const wanted = new Set(recipeIds);
  const safe = recipes
    .filter((r) => wanted.has(r.id) && isRecipeSafe(r, foods, union))
    .map((r) => r.id);
  return { restricted: true, safeRecipeIds: [...new Set(safe)].sort() };
}

/** Šest nizova kratkih tekstova i omiljeni (id recepta → broj članova). */
export function project(raw: unknown): Tastes {
  if (typeof raw !== "object" || raw === null) {
    throw new Error("planning_inputs_shape");
  }
  const source = raw as Record<string, unknown>;
  const result = {} as Tastes;
  for (const key of tasteKeys) {
    const value = source[key];
    if (
      !Array.isArray(value) || value.length > maxItems ||
      !value.every((v) => typeof v === "string" && v.length <= 64)
    ) {
      throw new Error("planning_inputs_shape");
    }
    result[key] = value as string[];
  }
  const favorites = source.favoriteRecipeCounts;
  if (
    typeof favorites !== "object" || favorites === null ||
    Array.isArray(favorites)
  ) {
    throw new Error("planning_inputs_shape");
  }
  const entries = Object.entries(favorites);
  if (
    entries.length > maxItems ||
    !entries.every(([id, count]) =>
      id.length > 0 && id.length <= 64 && Number.isInteger(count) &&
      (count as number) >= 1 && (count as number) <= 100
    )
  ) {
    throw new Error("planning_inputs_shape");
  }
  result.favoriteRecipeCounts = Object.fromEntries(entries) as Record<
    string,
    number
  >;
  return result;
}

export function planningInputs(deps: PlanningDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return failure(405, "method_not_allowed");
    }
    const token = /^Bearer ([^\s]+)$/i.exec(
      request.headers.get("Authorization") ?? "",
    )?.[1];
    if (!token) return failure(401, "unauthorized");
    try {
      const uid = await deps.authenticate(token);
      if (!uid) return failure(401, "unauthorized");
      if (!deps.allow(uid)) {
        return failure(429, "rate_limited");
      }
      const parsed = await parseRequest(request);
      if (!parsed) return failure(400, "bad_request");
      const expected = parsed.household;
      // Domaćinstvo se promenilo usred zahteva: ukusi novog ne idu u plan
      // starog. Aplikacija tada staje i ne pravi plan sa tuđim podacima.
      const household = await deps.householdOf(uid);
      if (household !== expected) return failure(409, "household_changed");
      const participants = await deps.membersOf(household);
      if (!participants.includes(uid)) {
        return failure(409, "household_changed");
      }
      if (parsed.recipeIds) {
        return respond(
          200,
          await planSafety(
            deps,
            { actor: uid, household, participants },
            parsed.recipeIds,
          ),
        );
      }
      const visibleFoodIds = await deps.visibleTasteFoods(
        household,
        participants,
      );
      const tastes = project(
        await deps.advisory({
          actor: uid,
          household,
          participants,
          visibleFoodIds,
        }),
      );
      return respond(200, tastes);
    } catch {
      return failure(500, "internal");
    }
  };
}

/** Id-jevi namirnica iz liked/disliked nizova profila (samo ispravni uuid). */
export function tasteFoodIds(profiles: unknown[]): string[] {
  const ids = new Set<string>();
  for (const p of profiles) {
    if (typeof p !== "object" || p === null) continue;
    for (const key of ["likedFoodIds", "dislikedFoodIds"]) {
      const list = (p as Record<string, unknown>)[key];
      if (!Array.isArray(list)) continue;
      for (const id of list) {
        if (typeof id === "string" && uuid.test(id)) ids.add(id);
      }
    }
  }
  return [...ids].sort().slice(0, maxItems);
}

export const isUuid = (value: string) => uuid.test(value);

/**
 * Ograničenje u memoriji jedne instance funkcije: najviše [limit] zahteva po
 * korisniku u minuti. Zaštita od petlje u aplikaciji, ne trajna kvota.
 */
export function minuteLimiter(limit: number, now: () => number = Date.now) {
  const windows = new Map<string, { start: number; count: number }>();
  return (uid: string): boolean => {
    const minute = Math.floor(now() / 60_000);
    const current = windows.get(uid);
    if (!current || current.start !== minute) {
      if (windows.size > 10_000) windows.clear();
      windows.set(uid, { start: minute, count: 1 });
      return true;
    }
    current.count++;
    return current.count <= limit;
  };
}
