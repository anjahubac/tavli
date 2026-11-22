// 006a: brisanje naloga (contracts/delete-account-function.md).
// Poziva ga aplikacija sa korisnikovim tokenom; service_role ključ daje
// platforma kroz okruženje funkcije (nikad u aplikaciji ni u repozitorijumu).
// Svaki korak je idempotentan: ponovljen poziv posle greške završava posao.
// Funkcija ne loguje tokene, adrese e-pošte ni imena objekata.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

// Privatni bucketi sa putanjom {household_id}/{ime}: slike recepata i kuvarske knjige.
const BUCKETS = ["recipe-photos", "cookbooks"];

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Briše sve objekte pod `{householdId}/` u jednom bucketu (po stranama). */
async function removeHouseholdObjects(
  admin: SupabaseClient,
  bucket: string,
  householdId: string,
): Promise<void> {
  while (true) {
    const { data, error } = await admin.storage
      .from(bucket)
      .list(householdId, { limit: 100 });
    if (error) throw error;
    if (!data || data.length === 0) return;
    const paths = data.map((o) => `${householdId}/${o.name}`);
    const { error: removeError } = await admin.storage.from(bucket).remove(paths);
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
    // 2. Slike i knjige domaćinstava u kojima je osoba jedini član.
    const { data: households, error: listError } = await admin.rpc(
      "solo_households",
      { uid },
    );
    if (listError) throw listError;
    for (const householdId of (households ?? []) as string[]) {
      for (const bucket of BUCKETS) {
        await removeHouseholdObjects(admin, bucket, householdId);
      }
    }

    // 3. Podaci (domaćinstvo sa svim podacima, članstvo, lični podaci, profil).
    const { error: rpcError } = await admin.rpc("delete_account_data", { uid });
    if (rpcError) throw rpcError;

    // 4. Nalog za prijavu.
    const { error: deleteError } = await admin.auth.admin.deleteUser(uid);
    if (deleteError && deleteError.status !== 404) throw deleteError;

    return json(200, { deleted: true });
  } catch (_) {
    return json(500, { error: "delete_failed" });
  }
});
