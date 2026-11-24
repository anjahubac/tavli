import {
  isUuid,
  minuteLimiter,
  planningInputs,
  tasteFoodIds,
} from "./planning.ts";
import type { FoodRow, RecipeRow } from "./plan_eligibility.ts";

const env = (name: string) => Deno.env.get(name);
const url = env("SUPABASE_URL");
const roleKey = env("SUPABASE_SERVICE_ROLE_KEY");
if (!url || !roleKey) throw new Error("missing_supabase_configuration");

function platform(path: string, token: string, args?: unknown) {
  return fetch(url + path, {
    method: args === undefined ? "GET" : "POST",
    headers: {
      apikey: roleKey!,
      Authorization: "Bearer " + token,
      "Content-Type": "application/json",
    },
    body: args === undefined ? undefined : JSON.stringify(args),
    redirect: "error",
    signal: AbortSignal.timeout(5000),
  });
}

/** Čita kao service role; greška baca, telo odgovora se ne loguje. */
async function read(path: string, args?: unknown): Promise<unknown> {
  const result = await platform(path, roleKey!, args);
  if (!result.ok) {
    await result.body?.cancel().catch(() => {});
    throw new Error("planning_inputs_read_failed");
  }
  return await result.json();
}

/** Čita u delovima, da adresa zahteva ostane kratka. */
async function inChunks<T>(
  ids: string[],
  readChunk: (chunk: string[]) => Promise<T[]>,
): Promise<T[]> {
  const result: T[] = [];
  for (let i = 0; i < ids.length; i += 100) {
    result.push(...await readChunk(ids.slice(i, i + 100)));
  }
  return result;
}

const rows = (value: unknown) =>
  Array.isArray(value)
    ? value.filter((r): r is Record<string, unknown> =>
      typeof r === "object" && r !== null
    )
    : [];

Deno.serve(planningInputs({
  async authenticate(token) {
    const result = await platform("/auth/v1/user", token);
    if (result.status === 401 || result.status === 403) {
      await result.body?.cancel().catch(() => {});
      return null;
    }
    if (!result.ok) {
      await result.body?.cancel().catch(() => {});
      throw new Error("planning_inputs_auth_failed");
    }
    const user = await result.json() as Record<string, unknown> | null;
    return typeof user?.id === "string" && user.is_anonymous !== true
      ? user.id
      : null;
  },
  async householdOf(uid) {
    if (!isUuid(uid)) return null;
    const found = rows(
      await read(
        `/rest/v1/household_members?select=household_id&user_id=eq.${uid}`,
      ),
    );
    const id = found[0]?.household_id;
    return found.length === 1 && typeof id === "string" ? id : null;
  },
  async membersOf(household) {
    return rows(
      await read(
        `/rest/v1/household_members?select=user_id&household_id=eq.${household}`,
      ),
    ).map((r) => r.user_id).filter((id): id is string =>
      typeof id === "string"
    );
  },
  async visibleTasteFoods(household, participants) {
    // Samo namirnice iz ukusa učesnika (mali skup), a ne ceo katalog:
    // deljene ili ovog domaćinstva, i nepovučene. Pristanak proverava RPC.
    const profiles = rows(
      await read(
        `/rest/v1/taste_profiles?select=profile&user_id=in.(${
          participants.filter(isUuid).join(",")
        })`,
      ),
    ).map((r) => r.profile);
    const ids = tasteFoodIds(profiles);
    if (ids.length === 0) return [];
    return rows(
      await read(
        `/rest/v1/foods?select=id&id=in.(${ids.join(",")})` +
          `&withdrawn_at=is.null&or=(household_id.is.null,household_id.eq.${household})`,
      ),
    ).map((r) => r.id).filter((id): id is string => typeof id === "string");
  },
  advisory({ actor, household, participants, visibleFoodIds }) {
    return read("/rest/v1/rpc/planning_advisory_inputs", {
      actor_id: actor,
      target_household: household,
      participant_ids: participants,
      for_provider: true,
      visible_food_ids: visibleFoodIds,
    });
  },
  allergenUnion({ actor, household, participants }) {
    return read("/rest/v1/rpc/planning_allergen_codes", {
      actor_id: actor,
      target_household: household,
      participant_ids: participants,
    });
  },
  recipes(household, ids) {
    // Id-jeve je već proverio parseRequest (slova, cifre, - i _).
    return inChunks(ids, async (chunk) =>
      rows(
        await read(
          `/rest/v1/recipes?select=id,ingredients&household_id=eq.${household}` +
            `&id=in.(${chunk.map((id) => `"${id}"`).join(",")})`,
        ),
      ).filter((r): r is RecipeRow & Record<string, unknown> =>
        typeof r.id === "string"
      ));
  },
  foods(ids) {
    return inChunks(ids.filter(isUuid), async (chunk) =>
      rows(
        await read(
          "/rest/v1/foods?select=id,household_id,withdrawn_at," +
            `allergen_codes,allergen_reviewed_at&id=in.(${chunk.join(",")})`,
        ),
      ).filter((r): r is FoodRow & Record<string, unknown> =>
        typeof r.id === "string"
      ));
  },
  // Plan čita ukuse i bezbednost pre svakog rasporeda i na kraju.
  allow: minuteLimiter(60),
}));
