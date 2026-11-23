// cookbook-ask: pitanje nad knjigama domaćinstva (spec 026, FR-003). Poziva ga
// aplikacija sa korisnikovim tokenom. Telo: {question, bookId?}. Kvota se
// rezerviše istim ai_reserve/ai_release kao u ai-gateway (015). Ključevi su
// samo u okruženju funkcije. Logika i provere su u ask.ts.

import { createClient } from "npm:@supabase/supabase-js@2";

import {
  createEmbedder,
  DEFAULT_EMBEDDING_MODEL,
} from "../cookbook-process/embed.ts";
import { ask, type AskDeps, type Hit } from "./ask.ts";
import { createGenerator } from "./generate.ts";

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const env = (name: string) => Deno.env.get(name);
const intEnv = (name: string, fallback: number) => {
  const v = Number(env(name));
  return Number.isInteger(v) && v > 0 ? v : fallback;
};

const admin = createClient(
  env("SUPABASE_URL")!,
  env("SUPABASE_SERVICE_ROLE_KEY")!,
  {
    auth: { persistSession: false, autoRefreshToken: false },
  },
);
const embeddingModel = env("EMBEDDING_MODEL") || DEFAULT_EMBEDDING_MODEL;
const embed = createEmbedder({
  apiKey: env("GEMINI_API_KEY") ?? "",
  model: embeddingModel,
});
const generate = createGenerator({ env });

const deps: AskDeps = {
  reserve: async (userId) => {
    const { data, error } = await admin.rpc("ai_reserve", {
      p_user_id: userId,
      p_kind: "text",
      p_daily_limit: intEnv("AI_DAILY_TEXT_LIMIT", 150),
      p_minute_limit: intEnv("AI_PER_MINUTE_LIMIT", 20),
      p_concurrent_limit: intEnv("AI_CONCURRENT_LIMIT", 2),
      p_global_limit: intEnv("AI_GLOBAL_DAILY_LIMIT", 2000),
    });
    if (error) throw error;
    const r = data as {
      id?: string;
      limit?: "daily" | "minute" | "concurrent" | "global";
      retry_after_seconds?: number;
    };
    if (typeof r?.id === "string") return { id: r.id };
    if (r?.limit) {
      return {
        limit: r.limit,
        retryAfterSeconds: Math.max(0, Math.ceil(r.retry_after_seconds ?? 60)),
      };
    }
    throw new Error("ai_reserve: unexpected result");
  },
  release: async (id) => {
    const { error } = await admin.rpc("ai_release", { p_id: id });
    if (error) throw error;
  },
  embedQuery: async (text) => (await embed([text], "query"))[0],
  search: async (userId, embedding, limit, bookId) => {
    const { data, error } = await admin.rpc("cookbook_search", {
      p_user_id: userId,
      p_embedding: `[${embedding.join(",")}]`,
      p_limit: limit,
      p_embedding_model: embeddingModel,
      p_book_id: bookId ?? null,
    });
    if (error) throw error;
    return ((data ?? []) as {
      chunk_id: string;
      cookbook_id: string;
      title: string;
      page: number;
      content: string;
      score: number;
    }[]).map((r): Hit => ({
      chunkId: r.chunk_id,
      cookbookId: r.cookbook_id,
      title: r.title,
      page: r.page,
      content: r.content,
      score: r.score,
    }));
  },
  generate,
  minScore: Number(env("COOKBOOK_MIN_SCORE")) || 0.55,
};

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  const token = (req.headers.get("Authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  ).trim();
  if (!token) return json(401, { error: "unauthorized" });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData?.user) return json(401, { error: "unauthorized" });

  let body: { question?: unknown; bookId?: unknown };
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "bad_request" });
  }
  try {
    const r = await ask(deps, userData.user.id, body);
    if (r.ok) {
      return json(200, {
        status: r.status,
        content: r.content,
        sources: r.sources,
      });
    }
    if (r.error === "quota_exceeded") {
      return json(429, {
        error: "quota_exceeded",
        retryAfterSeconds: r.retryAfterSeconds,
      });
    }
    return json(r.error === "bad_request" ? 400 : 502, { error: r.error });
  } catch {
    return json(500, { error: "internal" });
  }
});
