import { timingSafeEqual } from "node:crypto";
import { createClient } from "npm:@supabase/supabase-js@2";
import { cleanHouseholdPhotos, type CleanupBatch } from "./worker.ts";

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return new Response(null, { status: 405 });
  const token = Deno.env.get("HOUSEHOLD_PHOTO_CLEANUP_TOKEN");
  const bearer = request.headers.get("Authorization")?.match(/^Bearer (\S+)$/i)
    ?.[1];
  const encoder = new TextEncoder();
  if (!token || token.length < 32 || !bearer) {
    return new Response(null, { status: 401 });
  }
  const expected = encoder.encode(token);
  const supplied = encoder.encode(bearer);
  if (
    supplied.length !== expected.length || !timingSafeEqual(supplied, expected)
  ) {
    return new Response(null, { status: 401 });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  try {
    await cleanHouseholdPhotos({
      async claim() {
        const { data, error } = await admin.rpc(
          "claim_household_photo_cleanup",
        );
        if (error) throw error;
        return data as CleanupBatch;
      },
      async remove(paths) {
        const { error } = await admin.storage.from("recipe-photos").remove(
          paths,
        );
        if (error) throw error;
      },
      async complete(stagedClaim, retiredId) {
        const { error } = await admin.rpc("complete_household_photo_cleanup", {
          staged_claim_id: stagedClaim,
          retired_household_id: retiredId,
        });
        if (error) throw error;
      },
    });
    return new Response(null, { status: 204 });
  } catch {
    return new Response(null, { status: 503 });
  }
});
