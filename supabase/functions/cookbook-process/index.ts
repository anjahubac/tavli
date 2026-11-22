// cookbook-process: registruje i obrađuje otpremljenu knjigu (spec 026, FR-001,
// FR-002). Poziva ga aplikacija sa korisnikovim tokenom; ključevi dolaze samo
// iz okruženja funkcije. Telo: {storagePath, title} (nova knjiga) ili
// {bookId} (nastavak posle `partial`). Ne loguje tekst knjige ni tokene.
// Logika je u register.ts i process.ts; testovi su pored njih.

import { createClient } from "npm:@supabase/supabase-js@2";

import { createEmbedder } from "./embed.ts";
import { ExtractError, extractEpubPages, extractPdfPages } from "./extract.ts";
import {
  type Book,
  type ChunkRow,
  type ProcessDeps,
  processBook,
} from "./process.ts";
import { LimitReachedError, registerBook, type RegisterDeps } from "./register.ts";

const BUCKET = "cookbooks";

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const embedder = createEmbedder({
  apiKey: Deno.env.get("GEMINI_API_KEY") ?? "",
  model: Deno.env.get("EMBEDDING_MODEL") || undefined,
});

type Row = {
  id: string;
  household_id: string;
  storage_path: string;
  filename: string;
  status: Book["status"];
  next_page: number;
  pages: number | null;
  error_code: string | null;
};

const toBook = (r: Row): Book => ({
  id: r.id,
  householdId: r.household_id,
  storagePath: r.storage_path,
  filename: r.filename,
  status: r.status,
  nextPage: r.next_page,
  pages: r.pages,
  errorCode: r.error_code,
});

async function isMember(userId: string, householdId: string): Promise<boolean> {
  const { data, error } = await admin
    .from("household_members")
    .select("user_id")
    .eq("user_id", userId)
    .eq("household_id", householdId)
    .limit(1);
  if (error) throw error;
  return (data?.length ?? 0) > 0;
}

const registerDeps: RegisterDeps = {
  isMember,
  objectExists: async (path) => {
    const [folder, name] = path.split("/");
    const { data, error } = await admin.storage.from(BUCKET).list(folder, {
      limit: 5,
      search: name,
    });
    if (error) throw error;
    return (data ?? []).some((o) => o.name === name);
  },
  countBooks: async (householdId) => {
    const { count, error } = await admin
      .from("cookbooks")
      .select("id", { count: "exact", head: true })
      .eq("household_id", householdId);
    if (error) throw error;
    return count ?? 0;
  },
  findByPath: async (householdId, path) => {
    const { data, error } = await admin
      .from("cookbooks")
      .select("id,status")
      .eq("household_id", householdId)
      .eq("storage_path", path)
      .maybeSingle();
    if (error) throw error;
    return data ? { id: data.id, status: data.status } : null;
  },
  createBook: async (b) => {
    const { data, error } = await admin
      .from("cookbooks")
      .insert({
        household_id: b.householdId,
        title: b.title,
        filename: b.filename as string,
        storage_path: b.path,
        created_by: b.userId,
      })
      .select("id,status")
      .single();
    // 23514 sa porukom iz okidača: trka dva zahteva prešla je granicu knjiga.
    if (error?.code === "23514" && error.message.includes("cookbook_limit")) {
      throw new LimitReachedError();
    }
    // 23505: dva istovremena zahteva za istu putanju; važi onaj koji je prvi upisan.
    if (error?.code === "23505") {
      const existing = await registerDeps.findByPath(b.householdId, b.path);
      if (existing) return existing;
    }
    if (error) throw error;
    return { id: data.id, status: data.status };
  },
};

const processDeps: ProcessDeps = {
  claim: async (id) => {
    const { data, error } = await admin.rpc("claim_cookbook", { p_id: id });
    if (error) throw error;
    return data === true;
  },
  unclaim: async (id) => {
    const { error } = await admin.rpc("release_cookbook", { p_id: id });
    if (error) throw error;
  },
  getBook: async (id) => {
    const { data, error } = await admin.from("cookbooks").select("*").eq("id", id).maybeSingle();
    if (error) throw error;
    return data ? toBook(data as Row) : null;
  },
  download: async (path) => {
    const { data, error } = await admin.storage.from(BUCKET).download(path);
    if (error || !data) throw error ?? new Error("download failed");
    return new Uint8Array(await data.arrayBuffer());
  },
  extract: (filename, bytes) => {
    if (/\.pdf$/i.test(filename)) return extractPdfPages(bytes);
    if (/\.epub$/i.test(filename)) return extractEpubPages(bytes);
    return Promise.reject(new ExtractError("corrupt"));
  },
  embed: (texts) => embedder(texts, "document"),
  insertChunks: async (rows: ChunkRow[]) => {
    const { error } = await admin.from("cookbook_chunks").upsert(
      rows.map((r) => ({
        cookbook_id: r.cookbookId,
        household_id: r.householdId,
        page: r.page,
        chunk_index: r.chunkIndex,
        content: r.content,
        embedding: `[${r.embedding.join(",")}]`,
      })),
      { onConflict: "cookbook_id,page,chunk_index", ignoreDuplicates: true },
    );
    if (error) throw error;
  },
  updateBook: async (id, patch) => {
    const row: Record<string, unknown> = { updated_at: new Date().toISOString() };
    if (patch.status !== undefined) row.status = patch.status;
    if (patch.nextPage !== undefined) row.next_page = patch.nextPage;
    if (patch.pages !== undefined) row.pages = patch.pages;
    if (patch.errorCode !== undefined) row.error_code = patch.errorCode;
    const { error } = await admin.from("cookbooks").update(row).eq("id", id);
    if (error) throw error;
  },
  now: () => Date.now(),
};

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return json(401, { error: "unauthorized" });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData?.user) return json(401, { error: "unauthorized" });
  const userId = userData.user.id;

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "bad_request" });
  }

  try {
    let bookId: string;
    if (typeof body.bookId === "string") {
      const book = await processDeps.getBook(body.bookId);
      // Tuđa i nepostojeća knjiga daju isti odgovor.
      if (!book || !(await isMember(userId, book.householdId))) {
        return json(404, { error: "not_found" });
      }
      bookId = book.id;
    } else {
      const r = await registerBook(registerDeps, userId, {
        storagePath: body.storagePath,
        title: body.title,
      });
      if (!r.ok) {
        const status = { bad_request: 400, forbidden: 403, not_found: 404, limit_reached: 409 }[r.error];
        return json(status, { error: r.error });
      }
      bookId = r.id;
    }
    const result = await processBook(processDeps, bookId);
    const book = await processDeps.getBook(bookId);
    return json(200, {
      id: bookId,
      status: result.status,
      nextPage: result.nextPage,
      pages: book?.pages ?? null,
      errorCode: book?.errorCode ?? null,
    });
  } catch {
    return json(500, { error: "internal" });
  }
});
