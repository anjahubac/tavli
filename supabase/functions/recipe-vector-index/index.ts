import { timingSafeEqual } from "node:crypto";
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  embedRecipeVectors,
  recipeVectorProvider,
} from "../ai-gateway/recipe_vectors.ts";

interface PendingRecipe {
  recipe_id: string;
  lease: string;
  content: string;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  const token = Deno.env.get("RECIPE_VECTOR_INDEX_TOKEN");
  const bearer = request.headers.get("Authorization")?.match(/^Bearer (\S+)$/i)
    ?.[1];
  const encoder = new TextEncoder();
  if (
    !token || token.length < 32 || !bearer || bearer.length !== token.length
  ) {
    return new Response(null, { status: 401 });
  }
  const expected = encoder.encode(token);
  const supplied = encoder.encode(bearer);
  if (
    supplied.length !== expected.length || !timingSafeEqual(supplied, expected)
  ) return new Response(null, { status: 401 });

  const provider = recipeVectorProvider((name) => Deno.env.get(name));
  if (!provider || Deno.env.get("AI_GATEWAY_DISABLED") === "1") {
    return new Response(null, { status: 503 });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  try {
    const { data, error } = await admin.rpc("claim_recipe_vectors");
    if (error) throw error;
    const jobs = data as PendingRecipe[];
    if (jobs.length > 0) {
      const vectors = await embedRecipeVectors(
        jobs.map((job) => job.content),
        provider,
        fetch,
      );
      const writes = await Promise.all(
        jobs.map((job, index) =>
          admin.rpc("complete_recipe_vector", {
            p_recipe_id: job.recipe_id,
            p_lease: job.lease,
            p_embedding: JSON.stringify(vectors[index]),
          })
        ),
      );
      // A false result means an intervening edit or deletion invalidated
      // the lease. The new revision remains queued.
      if (writes.some((write) => write.error)) throw new Error("write_failed");
    }
    return new Response(null, { status: 204 });
  } catch {
    // Unfinished leases become eligible for retry without logging recipes.
    return new Response(null, { status: 503 });
  }
});
