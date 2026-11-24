import { gateway } from "./gateway.ts";
import { record } from "./input.ts";
import type { RankedRecipe } from "./recipe_vectors.ts";

const env = (name: string) => Deno.env.get(name);
const url = env("SUPABASE_URL");
const roleKey = env("SUPABASE_SERVICE_ROLE_KEY");
if (!url || !roleKey) throw new Error("missing_supabase_configuration");

const send: typeof fetch = (...args) => fetch(...args);

function platform(path: string, token: string, args?: Record<string, unknown>) {
  return send(url + path, {
    method: args ? "POST" : "GET",
    headers: {
      apikey: roleKey!,
      Authorization: "Bearer " + token,
      "Content-Type": "application/json",
    },
    body: args ? JSON.stringify(args) : undefined,
    redirect: "error",
    signal: AbortSignal.timeout(5000),
  });
}

async function rpc(name: string, args: Record<string, unknown>) {
  const result = await platform("/rest/v1/rpc/" + name, roleKey!, args);
  if (!result.ok) {
    await result.body?.cancel().catch(() => {});
    throw new Error("ai_quota_rpc_failed");
  }
  return result;
}

Deno.serve(gateway({
  env,
  send,
  async authenticate(token) {
    const result = await platform("/auth/v1/user", token);
    if (result.status === 401 || result.status === 403) {
      await result.body?.cancel().catch(() => {});
      return null;
    }
    if (!result.ok) {
      await result.body?.cancel().catch(() => {});
      throw new Error("ai_auth_lookup_failed");
    }
    const user = record(await result.json());
    return typeof user?.id === "string" && user.is_anonymous !== true
      ? user.id
      : null;
  },
  async enableRecipeIndexing(token, householdId) {
    const result = await platform(
      "/rest/v1/rpc/enable_recipe_vector_indexing",
      token,
      {
        p_household_id: householdId,
      },
    );
    if (!result.ok) {
      await result.body?.cancel().catch(() => {});
      throw new Error("recipe_vector_consent_failed");
    }
    return await result.json() === true;
  },
  async canSearchRecipes(token) {
    const result = await platform(
      "/rest/v1/rpc/can_search_recipe_vectors",
      token,
      {},
    );
    if (!result.ok) {
      await result.body?.cancel().catch(() => {});
      throw new Error("recipe_vector_consent_check_failed");
    }
    return await result.json() === true;
  },
  async rankRecipes(token, embedding, recipeIds) {
    const result = await platform("/rest/v1/rpc/rank_recipe_vectors", token, {
      p_embedding: JSON.stringify(embedding),
      p_recipe_ids: recipeIds,
    });
    if (!result.ok) {
      await result.body?.cancel().catch(() => {});
      throw new Error("recipe_vector_rank_failed");
    }
    return await result.json() as RankedRecipe[];
  },
  async reserve(uid, kind, limits) {
    const result = await rpc("ai_reserve", {
      p_user_id: uid,
      p_kind: kind,
      p_daily_limit: limits.daily,
      p_minute_limit: limits.minute,
      p_concurrent_limit: limits.concurrent,
      p_global_limit: limits.global,
    });
    const value = record(await result.json());
    if (typeof value?.id === "string") return { id: value.id };
    const limit = value?.limit;
    const seconds = value?.retry_after_seconds;
    if (
      (limit === "daily" || limit === "global" || limit === "minute" ||
        limit === "concurrent") &&
      typeof seconds === "number" && Number.isSafeInteger(seconds) &&
      seconds >= 0
    ) {
      return { limit, retryAfterSeconds: seconds };
    }
    throw new Error("invalid_ai_quota_response");
  },
  async release(id) {
    const result = await rpc("ai_release", { p_id: id });
    await result.body?.cancel();
  },
  async reserveImage(uid, recipeId, limits) {
    const result = await rpc("ai_image_reserve", {
      p_user_id: uid,
      p_recipe_id: recipeId,
      p_user_limit: limits.user,
      p_project_limit: limits.project,
      p_attempt_limit: limits.attempts,
    });
    const value = record(await result.json());
    if (value?.error === "no_household") return { error: "no_household" };
    if (
      typeof value?.id === "string" && typeof value.household_id === "string"
    ) {
      return { id: value.id, householdId: value.household_id };
    }
    const limit = value?.limit;
    const seconds = value?.retry_after_seconds;
    if (
      (limit === "user" || limit === "project") &&
      typeof seconds === "number" && Number.isSafeInteger(seconds) &&
      seconds >= 0
    ) {
      return { limit, retryAfterSeconds: seconds };
    }
    throw new Error("invalid_ai_image_quota_response");
  },
  // Service role upisuje u {household_id}/ (domaćinstvo iz članstva, ne iz
  // zahteva aplikacije).
  async storeImage(householdId, file, jpeg) {
    if (
      !/^[0-9a-f-]{36}$/.test(householdId) ||
      !/^ai_[0-9a-f-]{36}\.jpg$/.test(file)
    ) {
      throw new Error("invalid_ai_image_path");
    }
    const result = await send(
      url + "/storage/v1/object/recipe-photos/" + householdId + "/" + file,
      {
        method: "POST",
        headers: {
          apikey: roleKey!,
          Authorization: "Bearer " + roleKey,
          "Content-Type": "image/jpeg",
          "x-upsert": "false",
        },
        body: jpeg.slice().buffer as ArrayBuffer,
        redirect: "error",
        signal: AbortSignal.timeout(15000),
      },
    );
    await result.body?.cancel().catch(() => {});
    if (!result.ok) throw new Error("ai_image_store_failed");
  },
}));
