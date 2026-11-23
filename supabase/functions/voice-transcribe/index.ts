// voice-transcribe: pravo povezivanje (Supabase Auth, ai_reserve/ai_release).
// Logika je u transcribe.ts; testovi su u transcribe_test.ts.
// GROQ_API_KEY je tajna funkcije (postavlja Dev 4), nikad u repozitorijumu.

import { createClient } from "npm:@supabase/supabase-js@2";

import { type Deps, handle } from "./transcribe.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const deps: Deps = {
  env: (name) => Deno.env.get(name),
  getUserId: async (token) => {
    const { data, error } = await admin.auth.getUser(token);
    return error || !data?.user ? null : data.user.id;
  },
  reserve: async (userId, limits) => {
    const { data, error } = await admin.rpc("ai_reserve", {
      p_user_id: userId,
      p_kind: "text",
      p_daily_limit: limits.daily,
      p_minute_limit: limits.minute,
      p_concurrent_limit: limits.concurrent,
      p_global_limit: limits.global,
    });
    if (error) throw error;
    const r = data as {
      id?: string;
      limit?: string;
      retry_after_seconds?: number;
    };
    if (typeof r?.id === "string") return { id: r.id };
    if (
      r?.limit === "daily" || r?.limit === "minute" ||
      r?.limit === "concurrent" || r?.limit === "global"
    ) {
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
  fetch: (input, init) => fetch(input, init),
  log: (line) => console.log(JSON.stringify(line)),
  now: () => Date.now(),
};

Deno.serve((req) => handle(req, deps));
