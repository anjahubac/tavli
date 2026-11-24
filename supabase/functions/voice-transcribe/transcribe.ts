// voice-transcribe: govor u tekst za glasovni nacrt recepta (spec 027,
// specs/027-voice-recipe-agent/contracts/voice-agent-contract.md).
//
// Redosled: 1. samo POST; 2. ko zove (token); 3. tip i veličina snimka;
// 4. rezervacija limita (ai_reserve, vrsta "text"); 5. tačno jedan poziv
// provajdera (Groq Whisper) sa ključem sa servera; 6. oslobađanje
// rezervacije, pa prepis ili tipizovana greška.
//
// Snimak i prepis se nikad ne upisuju u bazu, storage ni log; loguju se samo
// status, veličina snimka i trajanje. Greške nemaju telo provajdera.

export const MAX_AUDIO_BYTES = 3_000_000;
export const PROVIDER_TIMEOUT_MS = 30_000;
export const DEFAULT_MODEL = "whisper-large-v3";

/** Kontekst za Whisper (polje `prompt`): jezik, ekavica i mere, koje važe za
 * svaki recept. Namerno bez spiska namirnica: Whisper bi mogao da ih dopiše,
 * a nazive iz konteksta ispravlja agent (ugovor, „Transcription“). */
export const STT_PROMPT =
  "Recept na srpskom jeziku, ekavica. Mere: pola kile, kilogram, grama, " +
  "decilitar, litar, kašika, kašičica, šolja, čaša, prstohvat, glavica, čen, " +
  "veza, pakovanje, po ukusu.";
const GROQ_URL = "https://api.groq.com/openai/v1/audio/transcriptions";

/** Dozvoljeni tipovi snimka → ekstenzija za provajdera. */
export const AUDIO_TYPES: Record<string, string> = {
  "audio/mp4": "m4a",
  "audio/m4a": "m4a",
  "audio/x-m4a": "m4a",
  "audio/aac": "aac",
  "audio/mpeg": "mp3",
  "audio/wav": "wav",
  "audio/x-wav": "wav",
  "audio/webm": "webm",
  "audio/ogg": "ogg",
  "audio/flac": "flac",
};

export interface Limits {
  daily: number;
  minute: number;
  concurrent: number;
  global: number;
}

export type Reservation =
  | { id: string }
  | {
    limit: "daily" | "minute" | "concurrent" | "global";
    retryAfterSeconds: number;
  };

export interface Deps {
  env: (name: string) => string | undefined;
  getUserId: (token: string) => Promise<string | null>;
  reserve: (userId: string, limits: Limits) => Promise<Reservation>;
  release: (id: string) => Promise<void>;
  fetch: typeof fetch;
  log: (line: Record<string, unknown>) => void;
  now: () => number;
}

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function intEnv(deps: Deps, name: string, fallback: number): number {
  const v = Number(deps.env(name));
  return Number.isInteger(v) && v > 0 ? v : fallback;
}

/** Odluka (a): snimak troši tekstualni limit (AI_* iz okruženja). */
export function limitsFor(deps: Deps): Limits {
  return {
    daily: intEnv(deps, "AI_DAILY_TEXT_LIMIT", 150),
    minute: intEnv(deps, "AI_PER_MINUTE_LIMIT", 20),
    concurrent: intEnv(deps, "AI_CONCURRENT_LIMIT", 2),
    global: intEnv(deps, "AI_GLOBAL_DAILY_LIMIT", 2000),
  };
}

function retryAfterSeconds(header: string | null): number | null {
  const h = Number(header?.trim());
  return header && Number.isFinite(h) && h >= 0 ? Math.ceil(h) : null;
}

async function transcribe(
  deps: Deps,
  audio: Uint8Array,
  type: string,
  key: string,
): Promise<Response> {
  const form = new FormData();
  form.append(
    "file",
    new Blob([audio as BlobPart], { type }),
    `speech.${AUDIO_TYPES[type]}`,
  );
  form.append("model", deps.env("VOICE_MODEL")?.trim() || DEFAULT_MODEL);
  form.append("language", "sr");
  form.append("response_format", "json");
  form.append("temperature", "0");
  form.append("prompt", STT_PROMPT);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), PROVIDER_TIMEOUT_MS);
  try {
    let res: Response;
    let body: string;
    try {
      res = await deps.fetch(GROQ_URL, {
        method: "POST",
        signal: controller.signal,
        headers: { Authorization: `Bearer ${key}` },
        body: form,
      });
      body = await res.text();
    } catch (_) {
      return controller.signal.aborted
        ? json(504, { error: "timeout" })
        : json(502, { error: "provider_error" });
    }
    if (res.status === 429) {
      const retry = retryAfterSeconds(res.headers.get("retry-after"));
      return json(429, {
        error: "provider_rate_limited",
        ...(retry === null ? {} : { retryAfterSeconds: retry }),
      });
    }
    if (!res.ok) return json(502, { error: "provider_error" });
    let text: unknown;
    try {
      text = JSON.parse(body)?.text;
    } catch (_) {
      text = undefined;
    }
    if (typeof text !== "string") return json(502, { error: "provider_error" });
    // Prazan prepis je ispravan odgovor („ništa nije izgovoreno“).
    return json(200, { text: text.trim() });
  } finally {
    clearTimeout(timer);
  }
}

export async function handle(req: Request, deps: Deps): Promise<Response> {
  const started = deps.now();
  // 1.
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  if (deps.env("AI_GATEWAY_DISABLED") === "1") {
    return json(503, { error: "model_unavailable" });
  }

  // 2.
  const token = (req.headers.get("Authorization") ?? "")
    .replace(/^Bearer\s+/i, "")
    .trim();
  const userId = token ? await deps.getUserId(token) : null;
  if (!userId) return json(401, { error: "unauthorized" });

  // 3. Tip i veličina pre čitanja i posle; ništa se ne troši za loš snimak.
  const type = (req.headers.get("Content-Type") ?? "").split(";")[0].trim()
    .toLowerCase();
  if (!AUDIO_TYPES[type]) return json(415, { error: "unsupported_type" });
  const declared = Number(req.headers.get("Content-Length"));
  if (Number.isFinite(declared) && declared > MAX_AUDIO_BYTES) {
    return json(413, { error: "too_large" });
  }
  const audio = new Uint8Array(await req.arrayBuffer());
  if (audio.length > MAX_AUDIO_BYTES) return json(413, { error: "too_large" });
  if (audio.length === 0) return json(400, { error: "bad_request" });

  const key = deps.env("GROQ_API_KEY")?.trim();
  if (!key) return json(503, { error: "model_unavailable" });

  // 4.
  let reservation: Reservation;
  try {
    reservation = await deps.reserve(userId, limitsFor(deps));
  } catch (_) {
    return json(500, { error: "internal" });
  }
  if (!("id" in reservation)) {
    deps.log({ fn: "voice-transcribe", status: 429 });
    return reservation.limit === "concurrent"
      ? json(429, {
        error: "busy",
        retryAfterSeconds: reservation.retryAfterSeconds,
      })
      : json(429, {
        error: "quota_exceeded",
        limit: reservation.limit,
        ...(reservation.limit === "daily" ? { kind: "text" } : {}),
        retryAfterSeconds: reservation.retryAfterSeconds,
      });
  }

  // 5. i 6.
  let res: Response;
  try {
    res = await transcribe(deps, audio, type, key);
  } finally {
    try {
      await deps.release(reservation.id);
    } catch (_) {
      // Red bez kraja prestaje da se broji kao „u toku“ posle 90 s.
    }
  }
  deps.log({
    fn: "voice-transcribe",
    status: res.status,
    bytes: audio.length,
    ms: deps.now() - started,
  });
  return res;
}
