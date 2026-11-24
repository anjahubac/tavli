// Testovi za voice-transcribe bez mreže, baze i pravih ključeva:
//   deno test supabase/functions/voice-transcribe/
import { assert, assertEquals, assertFalse } from "jsr:@std/assert@1";

import {
  type Deps,
  handle,
  type Limits,
  type Reservation,
  STT_PROMPT,
} from "./transcribe.ts";

const USER = "00000000-0000-4000-8000-000000000001";

interface Harness {
  deps: Deps;
  calls: { url: string; headers: Record<string, string>; form: FormData }[];
  reserves: { userId: string; limits: Limits }[];
  released: string[];
  logs: Record<string, unknown>[];
}

function harness(opts: {
  env?: Record<string, string>;
  reservation?: Reservation | Error;
  provider?: (signal: AbortSignal) => Promise<Response>;
} = {}): Harness {
  const env: Record<string, string> = {
    GROQ_API_KEY: "test-groq-key",
    ...opts.env,
  };
  const h: Harness = {
    calls: [],
    reserves: [],
    released: [],
    logs: [],
    deps: undefined as unknown as Deps,
  };
  h.deps = {
    env: (name) => env[name],
    getUserId: (token) => Promise.resolve(token === "good-token" ? USER : null),
    reserve: (userId, limits) => {
      h.reserves.push({ userId, limits });
      const r = opts.reservation ?? { id: "row-1" };
      return r instanceof Error ? Promise.reject(r) : Promise.resolve(r);
    },
    release: (id) => {
      h.released.push(id);
      return Promise.resolve();
    },
    fetch: (input, init) => {
      h.calls.push({
        url: String(input),
        headers: init?.headers as Record<string, string>,
        form: init?.body as FormData,
      });
      return opts.provider
        ? opts.provider(init!.signal!)
        : Promise.resolve(Response.json({ text: " Dodaj kilogram mesa. " }));
    },
    log: (line) => h.logs.push(line),
    now: () => 0,
  };
  return h;
}

function request(
  audio: Uint8Array | null,
  init: { token?: string | null; type?: string; method?: string } = {},
): Request {
  const headers: Record<string, string> = {
    "Content-Type": init.type ?? "audio/mp4",
  };
  const token = init.token === undefined ? "good-token" : init.token;
  if (token) headers.Authorization = `Bearer ${token}`;
  const method = init.method ?? "POST";
  return new Request("http://localhost/voice-transcribe", {
    method,
    headers,
    body: method === "GET" || audio === null ? undefined : audio as BodyInit,
  });
}

const audio = new Uint8Array([1, 2, 3, 4]);

async function call(h: Harness, req: Request) {
  const res = await handle(req, h.deps);
  return { status: res.status, body: await res.json() };
}

Deno.test("samo POST", async () => {
  const h = harness();
  assertEquals((await call(h, request(null, { method: "GET" }))).status, 405);
});

Deno.test("bez prijave: 401, bez rezervacije i poziva", async () => {
  for (const token of [null, "bad-token"]) {
    const h = harness();
    const r = await call(h, request(audio, { token }));
    assertEquals(r, { status: 401, body: { error: "unauthorized" } });
    assertEquals(h.reserves.length, 0);
    assertEquals(h.calls.length, 0);
  }
});

Deno.test("tip koji nije zvuk: 415, bez rezervacije", async () => {
  for (
    const type of ["application/json", "text/plain", "image/png", "video/mp4"]
  ) {
    const h = harness();
    const r = await call(h, request(audio, { type }));
    assertEquals(r, { status: 415, body: { error: "unsupported_type" } });
    assertEquals(h.reserves.length, 0);
  }
});

Deno.test("prevelik ili prazan snimak, bez rezervacije", async () => {
  const big = harness();
  const r = await call(big, request(new Uint8Array(3_000_001)));
  assertEquals(r, { status: 413, body: { error: "too_large" } });
  assertEquals(big.reserves.length, 0);

  const empty = harness();
  assertEquals((await call(empty, request(new Uint8Array(0)))).status, 400);
  assertEquals(empty.reserves.length, 0);
});

Deno.test("bez ključa ili ugašeno: 503 pre rezervacije", async () => {
  const envs: Record<string, string>[] = [
    { GROQ_API_KEY: "" },
    { AI_GATEWAY_DISABLED: "1" },
  ];
  for (const env of envs) {
    const h = harness({ env });
    const r = await call(h, request(audio));
    assertEquals(r, { status: 503, body: { error: "model_unavailable" } });
    assertEquals(h.reserves.length, 0);
  }
});

Deno.test("limit: tekstualni (odluka a), bez poziva provajdera", async () => {
  const h = harness({
    reservation: { limit: "daily", retryAfterSeconds: 3600 },
  });
  const r = await call(h, request(audio));
  assertEquals(r, {
    status: 429,
    body: {
      error: "quota_exceeded",
      limit: "daily",
      kind: "text",
      retryAfterSeconds: 3600,
    },
  });
  assertEquals(h.calls.length, 0);
  assertEquals(h.reserves[0].limits.daily, 150);

  const busy = harness({
    reservation: { limit: "concurrent", retryAfterSeconds: 5 },
  });
  assertEquals((await call(busy, request(audio))).body, {
    error: "busy",
    retryAfterSeconds: 5,
  });
});

Deno.test("greška baze: 500, bez poziva", async () => {
  const h = harness({ reservation: new Error("rpc") });
  assertEquals(await call(h, request(audio)), {
    status: 500,
    body: { error: "internal" },
  });
  assertEquals(h.calls.length, 0);
});

Deno.test("uspeh: jedan poziv Groq-u, srpski, ključ sa servera, prepis bez razmaka", async () => {
  const h = harness();
  const r = await call(h, request(audio, { type: "audio/x-m4a" }));
  assertEquals(r, { status: 200, body: { text: "Dodaj kilogram mesa." } });
  assertEquals(h.calls.length, 1);
  const c = h.calls[0];
  assertEquals(c.url, "https://api.groq.com/openai/v1/audio/transcriptions");
  assertEquals(c.headers.Authorization, "Bearer test-groq-key");
  assertEquals(c.form.get("model"), "whisper-large-v3");
  assertEquals(c.form.get("language"), "sr");
  assertEquals(c.form.get("prompt"), STT_PROMPT);
  const file = c.form.get("file") as File;
  assertEquals(file.name, "speech.m4a");
  assertEquals(file.size, 4);
  assertEquals(h.released, ["row-1"]);
});

Deno.test("model iz tajne VOICE_MODEL", async () => {
  const h = harness({ env: { VOICE_MODEL: "whisper-large-v3-turbo" } });
  await call(h, request(audio));
  assertEquals(h.calls[0].form.get("model"), "whisper-large-v3-turbo");
});

Deno.test("odgovori provajdera postaju greške iz ugovora; rezervacija se uvek oslobađa", async () => {
  const cases: [Response, number, Record<string, unknown>][] = [
    [
      new Response("{}", { status: 429, headers: { "retry-after": "9" } }),
      429,
      { error: "provider_rate_limited", retryAfterSeconds: 9 },
    ],
    [new Response("{}", { status: 400 }), 502, { error: "provider_error" }],
    [new Response("{}", { status: 500 }), 502, { error: "provider_error" }],
    [Response.json({ nothing: true }), 502, { error: "provider_error" }],
    [new Response("not json", { status: 200 }), 502, {
      error: "provider_error",
    }],
  ];
  for (const [providerRes, status, body] of cases) {
    const h = harness({ provider: () => Promise.resolve(providerRes) });
    assertEquals(await call(h, request(audio)), { status, body });
    assertEquals(h.released, ["row-1"]);
  }
});

Deno.test("prazan prepis je ispravan odgovor", async () => {
  const h = harness({
    provider: () => Promise.resolve(Response.json({ text: "  " })),
  });
  assertEquals(await call(h, request(audio)), {
    status: 200,
    body: { text: "" },
  });
});

Deno.test("mreža pala: 502; rok istekao: 504", async () => {
  const down = harness({
    provider: () => Promise.reject(new TypeError("net")),
  });
  assertEquals((await call(down, request(audio))).status, 502);

  const slow = harness({
    provider: (signal) =>
      new Promise((_, reject) =>
        signal.addEventListener("abort", () => reject(new Error("aborted")))
      ),
  });
  const realSetTimeout = globalThis.setTimeout;
  globalThis.setTimeout =
    ((fn: () => void) => realSetTimeout(fn, 1)) as typeof setTimeout;
  try {
    assertEquals(await call(slow, request(audio)), {
      status: 504,
      body: { error: "timeout" },
    });
    assertEquals(slow.released, ["row-1"]);
  } finally {
    globalThis.setTimeout = realSetTimeout;
  }
});

Deno.test("ni prepis ni greška provajdera ne idu u log ni u odgovor", async () => {
  const h = harness({
    provider: () =>
      Promise.resolve(
        new Response('{"error":"secret test-groq-key"}', { status: 500 }),
      ),
  });
  const res = await handle(request(audio), h.deps);
  assertFalse((await res.text()).includes("secret"));

  const ok = harness();
  await call(ok, request(audio));
  assertEquals(Object.keys(ok.logs[0]).sort(), ["bytes", "fn", "ms", "status"]);
  assert(!JSON.stringify(ok.logs).includes("mesa"));
});
