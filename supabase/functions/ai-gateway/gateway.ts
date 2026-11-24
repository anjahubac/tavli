import {
  BodyTooLarge,
  boundedJson,
  type Completion,
  maxBodyBytes,
  parseCompletion,
  record,
} from "./input.ts";
import {
  generateImage,
  type ImageLimits,
  imageLimits,
  imageProvider,
  type ImageReservation,
  imageTask,
  maxImageRequestBytes,
  parseImageRequest,
} from "./image.ts";
import {
  type Env,
  type Kind,
  modelId,
  orderedChain,
  providerOrder,
  resolveModel,
} from "./providers.ts";

const maxProviderResponseBytes = 256_000;

type QuotaLimit = "daily" | "global" | "minute" | "concurrent";

export type Reservation =
  | { id: string }
  | { limit: QuotaLimit; retryAfterSeconds: number };

export interface Limits {
  daily: number;
  minute: number;
  concurrent: number;
  global: number;
}

interface GatewayDependencies {
  env: Env;
  authenticate(token: string): Promise<string | null>;
  reserve(uid: string, kind: Kind, limits: Limits): Promise<Reservation>;
  release(id: string): Promise<void>;
  reserveImage(
    uid: string,
    recipeId: string,
    limits: ImageLimits,
  ): Promise<ImageReservation>;
  storeImage(
    householdId: string,
    file: string,
    jpeg: Uint8Array,
  ): Promise<void>;
  send: typeof fetch;
}

function response(status: number, body: Record<string, unknown>, headers = {}) {
  return Response.json(body, {
    status,
    headers: { "Cache-Control": "no-store", ...headers },
  });
}

function failure(status: number, error: string) {
  return response(status, { error });
}

function limit(env: Env, name: string, fallback: number): number {
  const raw = env(name);
  if (raw === undefined) return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > 2_147_483_647) {
    throw new Error("invalid_gateway_limit");
  }
  return value;
}

function limitsFor(env: Env, kind: Kind): Limits {
  return {
    daily: kind === "vision"
      ? limit(env, "AI_DAILY_VISION_LIMIT", 30)
      : limit(env, "AI_DAILY_TEXT_LIMIT", 150),
    minute: limit(env, "AI_PER_MINUTE_LIMIT", 20),
    concurrent: limit(env, "AI_CONCURRENT_LIMIT", 2),
    global: limit(env, "AI_GLOBAL_DAILY_LIMIT", 2000),
  };
}

function quotaResponse(
  denied: Extract<Reservation, { limit: QuotaLimit }>,
  kind: Kind,
) {
  const { limit, retryAfterSeconds } = denied;
  if (limit === "concurrent") {
    return response(429, { error: "busy", retryAfterSeconds });
  }
  return response(429, {
    error: "quota_exceeded",
    limit,
    ...(limit === "daily" ? { kind } : {}),
    retryAfterSeconds,
  });
}

async function complete(
  input: Completion,
  selected: NonNullable<ReturnType<typeof resolveModel>>,
  send: typeof fetch,
): Promise<Response> {
  const { key, model, tokenField, url } = selected;
  const signal = AbortSignal.timeout(model.timeoutSeconds * 1000);
  try {
    const upstream = await send(url, {
      method: "POST",
      redirect: "error",
      signal,
      headers: {
        Authorization: "Bearer " + key,
        "Content-Type": "application/json",
        ...(model.provider === "openrouter" ? { "X-Title": "Tavli" } : {}),
      },
      body: JSON.stringify({
        model: model.name,
        [tokenField]: 4096,
        response_format: { type: "json_object" },
        ...(model.provider === "openai"
          ? {}
          : { temperature: input.temperature }),
        // Lowest effort (contract D3): reasoning tokens count toward the
        // 4096 limit and the deadline.
        ...(model.provider === "openai" || model.name === "qwen/qwen3.6-27b"
          ? { reasoning_effort: "none" }
          : {}),
        messages: [
          { role: "system", content: input.system },
          {
            role: "user",
            content: input.image
              ? [
                { type: "text", text: input.prompt },
                { type: "image_url", image_url: { url: input.image } },
              ]
              : input.prompt,
          },
        ],
      }),
    });

    if (!upstream.ok) {
      await upstream.body?.cancel().catch(() => {});
      if (upstream.status === 404) return failure(503, "model_unavailable");
      if (upstream.status === 429) {
        const retry = upstream.headers.get("Retry-After");
        const seconds = retry && /^\d+$/.test(retry) ? Number(retry) : NaN;
        return response(429, {
          error: "provider_rate_limited",
          ...(Number.isSafeInteger(seconds)
            ? { retryAfterSeconds: seconds }
            : {}),
        });
      }
      return failure(502, "provider_error");
    }

    const payload = record(
      await boundedJson(upstream.body, maxProviderResponseBytes),
    );
    const first = Array.isArray(payload?.choices)
      ? record(payload.choices[0])
      : undefined;
    const content = record(first?.message)?.content;
    if (typeof content !== "string" || !content.trim()) {
      return failure(502, "provider_error");
    }
    return response(200, { content, model: input.model });
  } catch {
    return signal.aborted
      ? failure(504, "timeout")
      : failure(502, "provider_error");
  }
}

/** `recipe_image`: limiti, jedan poziv FLUX-a, upis u recipe-photos. */
async function recipeImage(
  raw: unknown,
  uid: string,
  { env, reserveImage, storeImage, send }: GatewayDependencies,
): Promise<Response> {
  const provider = imageProvider(env);
  if (!provider) return failure(503, "disabled");
  if (JSON.stringify(raw).length > maxImageRequestBytes) {
    return failure(413, "too_large");
  }
  const input = parseImageRequest(raw);
  if (!input) return failure(400, "bad_request");

  const reservation = await reserveImage(uid, input.recipeId, imageLimits(env));
  if ("error" in reservation) return failure(403, "forbidden");
  if ("limit" in reservation) {
    console.info("ai_image_quota_" + reservation.limit);
    return response(429, {
      error: "quota_exceeded",
      limit: reservation.limit,
      retryAfterSeconds: reservation.retryAfterSeconds,
    });
  }

  const result = await generateImage(provider, input.description, send);
  if (!result.ok) {
    // Samo vrsta greške: bez opisa, odgovora provajdera i ključeva.
    console.warn("ai_image_failed_" + String(result.body.error));
    return response(result.status, result.body);
  }
  const file = "ai_" + crypto.randomUUID() + ".jpg";
  await storeImage(reservation.householdId, file, result.jpeg);
  return response(200, {
    file,
    path: reservation.householdId + "/" + file,
  });
}

export function gateway(dependencies: GatewayDependencies) {
  const { env, authenticate, reserve, release, send } = dependencies;
  return async (request: Request): Promise<Response> => {
    if (request.method !== "GET" && request.method !== "POST") {
      return response(405, { error: "method_not_allowed" }, {
        Allow: "GET, POST",
      });
    }
    const token = /^Bearer ([^\s]+)$/i.exec(
      request.headers.get("Authorization") ?? "",
    )?.[1];
    if (!token) return failure(401, "unauthorized");

    try {
      const uid = await authenticate(token);
      if (!uid) return failure(401, "unauthorized");
      if (env("AI_GATEWAY_DISABLED") === "1") {
        return failure(503, "gateway_unavailable");
      }
      if (request.method === "GET") {
        const { ignored } = providerOrder(env);
        if (ignored.length > 0) {
          console.warn("ai_provider_order_ignored " + ignored.join(","));
        }
        const available = (kind: Kind) =>
          orderedChain(kind, env).filter((candidate) =>
            resolveModel(candidate, env)
          ).map(modelId);
        return response(200, {
          text: available("text"),
          vision: available("vision"),
        });
      }

      if (Number(request.headers.get("Content-Length")) > maxBodyBytes) {
        return failure(413, "too_large");
      }
      let raw: unknown;
      try {
        raw = await boundedJson(request.body, maxBodyBytes);
      } catch (error) {
        return error instanceof BodyTooLarge
          ? failure(413, "too_large")
          : failure(400, "bad_request");
      }
      if (record(raw)?.task === imageTask) {
        return await recipeImage(raw, uid, dependencies);
      }
      const input: Completion | undefined = parseCompletion(raw);
      if (!input) return failure(400, "bad_request");

      const candidate = orderedChain(input.kind, env).find((entry) =>
        modelId(entry) === input.model
      );
      if (!candidate) return failure(400, "bad_request");
      const selected = resolveModel(candidate, env);
      if (!selected) return failure(503, "model_unavailable");

      const reservation = await reserve(
        uid,
        input.kind,
        limitsFor(env, input.kind),
      );
      if ("limit" in reservation) return quotaResponse(reservation, input.kind);
      try {
        const result = await complete(input, selected, send);
        // Only the model id and status: no prompt, output, token or key.
        console.info(
          "ai_gateway_call model=" + input.model + " status=" + result.status,
        );
        return result;
      } finally {
        try {
          await release(reservation.id);
        } catch {
          // The RPC expires abandoned reservations after 90 seconds.
          console.warn("ai_gateway_release_failed");
        }
      }
    } catch {
      return failure(500, "internal");
    }
  };
}
