// Browser access for the web app (spec 036, contracts/cors.md).
// Native clients send no Origin and get the original response unchanged.

const allowedHeaders = "authorization, apikey, content-type, x-client-info";

function isLocalHttp(url: URL): boolean {
  return url.protocol === "http:" &&
    (url.hostname === "localhost" || url.hostname === "127.0.0.1");
}

/** Parses `TAVLI_WEB_ORIGINS` (comma-separated exact origins). Invalid items are dropped. */
export function parseOrigins(value: string | undefined | null): Set<string> {
  const result = new Set<string>();
  for (const raw of (value ?? "").split(",")) {
    const item = raw.trim();
    if (!item || item === "*" || item === "null") continue;
    let url: URL;
    try {
      url = new URL(item);
    } catch {
      continue;
    }
    const secure = url.protocol === "https:" || isLocalHttp(url);
    if (!secure || url.origin !== item) continue;
    result.add(url.origin);
  }
  return result;
}

type Handler = (request: Request) => Response | Promise<Response>;

function withHeaders(
  response: Response,
  extra: Record<string, string>,
): Response {
  const headers = new Headers(response.headers);
  for (const [name, value] of Object.entries(extra)) headers.set(name, value);
  headers.append("Vary", "Origin");
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

/**
 * Wraps a function handler. `origins` is read per request by default so a
 * changed environment value applies without code changes; tests inject it.
 */
export function withCors(
  handler: Handler,
  origins: () => Set<string> = () =>
    parseOrigins(Deno.env.get("TAVLI_WEB_ORIGINS")),
): Handler {
  return async (request) => {
    const origin = request.headers.get("Origin");
    const allowed = origin !== null && origins().has(origin);

    if (request.method === "OPTIONS") {
      if (!allowed) return new Response(null, { status: 204 });
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": origin,
          "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
          "Access-Control-Allow-Headers": allowedHeaders,
          "Access-Control-Max-Age": "600",
          "Vary": "Origin",
        },
      });
    }

    const response = await handler(request);
    if (!allowed) return response;
    return withHeaders(response, { "Access-Control-Allow-Origin": origin });
  };
}
