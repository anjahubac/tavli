// 006a: brisanje naloga (contracts/delete-account-function.md).
// Poziva ga aplikacija sa korisnikovim tokenom; service_role ključ daje
// platforma kroz okruženje funkcije (nikad u aplikaciji ni u repozitorijumu).
// Svaki korak je idempotentan: ponovljen poziv posle greške završava posao.
// Funkcija ne loguje tokene, adrese e-pošte ni imena objekata.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const BUCKET = "recipe-photos";

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Briše sve slike pod `{householdId}/` (po stranama). */
async function removeHouseholdPhotos(
  admin: SupabaseClient,
  uid: string,
  householdId: string,
): Promise<void> {
  while (true) {
    const { data: paths, error } = await admin.rpc("retired_household_photo_paths", {
      caller_id: uid,
      hid: householdId,
    });
    if (error) throw error;
    if (!paths?.length) return;
    const prefix = `${householdId}/`;
    for (const path of paths as string[]) {
      if (!path.startsWith(prefix) || path.slice(prefix.length).split("/").some(
        (part) => !part || part === "." || part === ".." || part.includes("\\"),
      )) {
        throw new Error("invalid_recipe_photo_path");
      }
    }
    const { error: removeError } = await admin.storage.from(BUCKET).remove(paths);
    if (removeError) throw removeError;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const token = (req.headers.get("Authorization") ?? "")
    .replace(/^Bearer\s+/i, "")
    .trim();
  if (!token) return json(401, { error: "unauthorized" });

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  // 1. Ko zove (provera tokena na Auth serveru).
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData?.user) return json(401, { error: "unauthorized" });
  const uid = userData.user.id;

  try {
    // 2. Članstvo, zajednički i lični podaci, uz upis u red za čišćenje.
    const { error: rpcError } = await admin.rpc("delete_account_data", { uid });
    if (rpcError) throw rpcError;

    // 3. Čisti samo ugašena domaćinstva. Red preživljava neuspeo poziv.
    while (true) {
      const { data: households, error: listError } = await admin.rpc(
        "household_join_photo_cleanup",
        { caller_id: uid, completed_id: null },
      );
      if (listError) throw listError;
      if (!households?.length) break;
      for (const householdId of households as string[]) {
        await removeHouseholdPhotos(admin, uid, householdId);
        const { error: cleanupError } = await admin.rpc(
          "household_join_photo_cleanup",
          { caller_id: uid, completed_id: householdId },
        );
        if (cleanupError) throw cleanupError;
      }
    }

    // 4. Nalog za prijavu.
    const { error: deleteError } = await admin.auth.admin.deleteUser(uid);
    if (deleteError && deleteError.status !== 404) throw deleteError;

    return json(200, { deleted: true });
  } catch (_) {
    return json(500, { error: "delete_failed" });
  }
});
