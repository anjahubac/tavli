// TRELLO-130: zadatak `recipe_image`. Aplikacija šalje samo id recepta i
// opis jela; adresa provajdera, model, stil i ključevi su ovde.
import { decodeBase64 } from "./base64.ts";
import { boundedJson, record } from "./input.ts";
import type { Env } from "./providers.ts";

export const imageTask = "recipe_image";
export const maxImageRequestBytes = 4_096;
export const maxDescriptionLength = 600;
const maxImageBytes = 5 * 1024 * 1024;
// Base64 je za trećinu veći od slike, plus omotač odgovora.
const maxProviderResponseBytes = 8_000_000;
const providerTimeoutMs = 45_000;

export const imageModel = "@cf/black-forest-labs/flux-1-schnell";
export const imageStyle =
  "Appetizing home-cooked food photography, top-down view, natural soft " +
  "daylight, rustic table, realistic, high detail, no text, no people, " +
  "no hands.";

export interface ImageRequest {
  recipeId: string;
  description: string;
}

export interface ImageLimits {
  user: number;
  project: number;
  attempts: number;
}

export type ImageReservation =
  | { id: string; householdId: string }
  | { limit: "user" | "project"; retryAfterSeconds: number }
  | { error: "no_household" };

export type ImageResult =
  | { ok: true; jpeg: Uint8Array }
  | { ok: false; status: number; body: Record<string, unknown> };

const fields = new Set(["task", "recipeId", "description"]);

/** Čisti opis: bez kontrolnih znakova i viška razmaka, najviše 600 znakova. */
export function cleanDescription(value: string): string {
  // deno-lint-ignore no-control-regex
  const text = value.replace(/[\u0000-\u001f\u007f]+/g, " ")
    .replace(/\s+/g, " ").trim();
  return text.length <= maxDescriptionLength
    ? text
    : text.slice(0, maxDescriptionLength).trimEnd();
}

export function parseImageRequest(value: unknown): ImageRequest | undefined {
  const body = record(value);
  if (!body || Object.keys(body).some((key) => !fields.has(key))) return;
  const { task, recipeId, description } = body;
  if (
    task !== imageTask || typeof recipeId !== "string" ||
    !/^[A-Za-z0-9_-]{1,64}$/.test(recipeId) ||
    typeof description !== "string"
  ) return;
  const cleaned = cleanDescription(description);
  if (cleaned.length < 10) return;
  return { recipeId, description: cleaned };
}

/** Opis jela + stalni stil; aplikacija ne bira stil ni model. */
export function imagePrompt(description: string): string {
  const text = cleanDescription(description);
  return /[.!?]$/.test(text)
    ? text + " " + imageStyle
    : text + ". " + imageStyle;
}

function positive(env: Env, name: string, fallback: number): number {
  const raw = env(name);
  if (raw === undefined || raw.trim() === "") return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > 1_000_000) {
    throw new Error("invalid_image_limit");
  }
  return value;
}

export function imageLimits(env: Env): ImageLimits {
  return {
    user: positive(env, "AI_IMAGES_USER_DAILY_LIMIT", 30),
    project: positive(env, "AI_IMAGES_DAILY_CAP", 60),
    attempts: positive(env, "AI_IMAGES_RECIPE_ATTEMPTS", 3),
  };
}

/** Slike su uključene samo uz AI_IMAGES_ENABLED=1 i oba Cloudflare podatka. */
export function imageProvider(env: Env) {
  if (env("AI_IMAGES_ENABLED") !== "1") return null;
  const account = env("CF_ACCOUNT_ID")?.trim();
  const token = env("CF_API_TOKEN")?.trim();
  if (!account || !token || !/^[A-Za-z0-9]{1,64}$/.test(account)) return null;
  return {
    url: "https://api.cloudflare.com/client/v4/accounts/" + account +
      "/ai/run/" + imageModel,
    token,
  };
}

function isJpeg(bytes: Uint8Array): boolean {
  return bytes.byteLength > 4 && bytes[0] === 0xff && bytes[1] === 0xd8 &&
    bytes[bytes.byteLength - 2] === 0xff &&
    bytes[bytes.byteLength - 1] === 0xd9;
}

function failure(status: number, error: string, extra = {}): ImageResult {
  return { ok: false, status, body: { error, ...extra } };
}

/** Jedan poziv FLUX schnell modela. Bez širine i visine (schnell ih odbija). */
export async function generateImage(
  provider: NonNullable<ReturnType<typeof imageProvider>>,
  description: string,
  send: typeof fetch,
): Promise<ImageResult> {
  const signal = AbortSignal.timeout(providerTimeoutMs);
  try {
    const upstream = await send(provider.url, {
      method: "POST",
      redirect: "error",
      signal,
      headers: {
        Authorization: "Bearer " + provider.token,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ prompt: imagePrompt(description), steps: 4 }),
    });
    if (!upstream.ok) {
      await upstream.body?.cancel().catch(() => {});
      if (upstream.status === 429) {
        const retry = upstream.headers.get("Retry-After");
        const seconds = retry && /^\d+$/.test(retry) ? Number(retry) : NaN;
        return failure(429, "rate_limited", {
          retryAfterSeconds: Number.isSafeInteger(seconds) && seconds <= 86400
            ? seconds
            : 60,
        });
      }
      return failure(502, "provider_error");
    }
    const payload = record(
      await boundedJson(upstream.body, maxProviderResponseBytes),
    );
    const image = record(payload?.result)?.image;
    if (typeof image !== "string" || !image) {
      return failure(502, "provider_error");
    }
    const jpeg = decodeBase64(image);
    if (jpeg.byteLength > maxImageBytes || !isJpeg(jpeg)) {
      return failure(502, "provider_error");
    }
    return { ok: true, jpeg };
  } catch {
    return signal.aborted
      ? failure(504, "timeout")
      : failure(502, "provider_error");
  }
}
