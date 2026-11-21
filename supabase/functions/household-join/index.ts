import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const bucket = "recipe-photos";
const uuid = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/;
const sourcePath = /^[0-9a-f-]{36}\/[A-Za-z0-9_-]{1,96}\.jpg$/;
const targetPath = /^[0-9a-f-]{36}\/joinphoto-[0-9a-f]{64}\.jpg$/;

function response(status: string, http = 200): Response {
  return Response.json({ status }, { status: http });
}

async function readBody(request: Request): Promise<Record<string, unknown> | null> {
  const reader = request.body?.getReader();
  if (!reader) return null;
  const decoder = new TextDecoder();
  let size = 0;
  let body = "";
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      size += chunk.value.byteLength;
      if (size > 2048) return null;
      body += decoder.decode(chunk.value, { stream: true });
    }
    const parsed: unknown = JSON.parse(body + decoder.decode());
    return typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)
      ? parsed as Record<string, unknown>
      : null;
  } catch {
    return null;
  } finally {
    await reader.cancel().catch(() => {});
  }
}

async function cleanRetiredHomes(admin: SupabaseClient, uid: string) {
  const scan = { caller_id: uid, completed_id: null };
  const { data, error } = await admin.rpc("household_join_photo_cleanup", scan);
  if (error || !Array.isArray(data)) return;
  const storage = admin.storage.from(bucket);
  for (const household of data) {
    if (typeof household !== "string" || !uuid.test(household)) continue;
    // Limit each invocation. The durable queue survives errors and timeouts.
    for (let page = 0; page < 10; page++) {
      const { data: rows, error: listError } = await storage.list(household, { limit: 100 });
      if (listError) break;
      if (!rows.length) {
        await admin.rpc("household_join_photo_cleanup", {
          ...scan,
          completed_id: household,
        });
        break;
      }
      const paths = rows
        .filter((row) => row.id !== null && /^[A-Za-z0-9_-]{1,96}\.jpg$/.test(row.name))
        .map((row) => `${household}/${row.name}`);
      if (!paths.length) break;
      const { error: removeError } = await storage.remove(paths);
      if (removeError) break;
    }
  }
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return response("method_not_allowed", 405);
  const bearer = request.headers.get("Authorization")?.match(/^Bearer (\S+)$/i)?.[1];
  const anonKey = request.headers.get("apikey");
  if (!bearer || !anonKey) return response("unauthorized", 401);

  const body = await readBody(request);
  const token = body?.token;
  const source = body?.expected_source_household_id;
  const choice = body?.recipe_choice;
  const ack = body?.source_deletion_ack;
  const operation = body?.operation_id;
  if (typeof token !== "string" || token.length > 80 ||
      typeof source !== "string" || !uuid.test(source) ||
      (choice !== "bring_recipes" && choice !== "leave_recipes") ||
      typeof ack !== "boolean" || typeof operation !== "string" || !uuid.test(operation)) {
    return response("invalid_request", 400);
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const auth = { persistSession: false, autoRefreshToken: false };
  const client = createClient(url, anonKey, {
    auth,
    global: { headers: { Authorization: `Bearer ${bearer}` } },
  });
  const { data: user, error: authError } = await client.auth.getUser(bearer);
  if (authError || !user.user) return response("unauthorized", 401);

  try {
    const { data: result, error } = await client.rpc("confirm_household_join", {
      token,
      expected_source_household_id: source,
      recipe_choice: choice,
      source_deletion_ack: ack,
      operation_id: operation,
    });
    if (error) return response("unavailable", 503);
    if (result?.status !== "photo_transfer_pending" && result?.status !== "joined") {
      return Response.json(result);
    }

    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth });
    const uid = user.user.id;
    let finalResult = result;
    if (result.status === "photo_transfer_pending") {
      const input = {
        caller_id: uid,
        token,
        source_id: source,
        recipe_choice: choice,
        source_deletion_ack: ack,
        operation_id: operation,
      };
      const { data: manifest, error: manifestError } = await admin.rpc(
        "prepare_household_join_photos",
        input,
      );
      if (manifestError) return response("unavailable", 503);
      if (manifest?.status !== "ready") return Response.json(manifest);
      const storage = admin.storage.from(bucket);
      for (const photo of manifest.photos) {
        if (!sourcePath.test(photo.source) || !targetPath.test(photo.destination) ||
            !photo.source.startsWith(`${source}/`)) {
          return response("photo_unavailable");
        }
        const { error: copyError } = await storage.copy(photo.source, photo.destination);
        if (copyError) {
          const { data: exists } = await storage.exists(photo.destination);
          if (!exists) return response("photo_transfer_retry");
        }
      }
      const { data: finished, error: finishError } = await admin.rpc(
        "finish_household_join_photos",
        { ...input, photos: manifest.photos },
      );
      if (finishError) return response("unavailable", 503);
      finalResult = finished;
    }

    if (finalResult?.status === "joined") {
      await cleanRetiredHomes(admin, uid).catch(() => {});
    }
    return Response.json(finalResult);
  } catch {
    return response("unavailable", 503);
  }
});
