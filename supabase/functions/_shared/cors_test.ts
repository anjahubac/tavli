import { assertEquals } from "jsr:@std/assert@1";
import { parseOrigins, withCors } from "./cors.ts";

const web = "https://tavli-dev.example.com";
const inner = (request: Request) =>
  request.headers.get("Authorization")
    ? Response.json({ ok: true })
    : Response.json({ error: "unauthorized" }, { status: 401 });
const handler = withCors(inner, () => parseOrigins(web));

function call(method: string, headers: Record<string, string> = {}) {
  return handler(new Request("https://fn.example/x", { method, headers }));
}

Deno.test("allowed origin preflight returns 204 with CORS headers", async () => {
  const r = await call("OPTIONS", { Origin: web });
  assertEquals(r.status, 204);
  assertEquals(r.headers.get("Access-Control-Allow-Origin"), web);
  assertEquals(
    r.headers.get("Access-Control-Allow-Headers"),
    "authorization, apikey, content-type, x-client-info",
  );
  assertEquals(r.headers.get("Vary"), "Origin");
});

Deno.test("foreign origin preflight has no allow headers", async () => {
  const r = await call("OPTIONS", { Origin: "https://evil.example" });
  assertEquals(r.status, 204);
  assertEquals(r.headers.get("Access-Control-Allow-Origin"), null);
});

Deno.test("foreign origin request is unchanged and without CORS", async () => {
  const r = await call("POST", {
    Origin: "https://evil.example",
    Authorization: "Bearer t",
  });
  assertEquals(r.status, 200);
  assertEquals(r.headers.get("Access-Control-Allow-Origin"), null);
});

Deno.test("allowed origin without session keeps 401 and gets the header", async () => {
  const r = await call("POST", { Origin: web });
  assertEquals(r.status, 401);
  assertEquals(await r.json(), { error: "unauthorized" });
  assertEquals(r.headers.get("Access-Control-Allow-Origin"), web);
});

Deno.test("no Origin (native client) gets the original response", async () => {
  const r = await call("POST", { Authorization: "Bearer t" });
  assertEquals(r.status, 200);
  assertEquals(await r.json(), { ok: true });
  assertEquals(r.headers.get("Access-Control-Allow-Origin"), null);
  assertEquals(r.headers.get("Vary"), null);
});

Deno.test("unset environment allows no origin", async () => {
  const none = withCors(inner, () => parseOrigins(undefined));
  const r = await none(
    new Request("https://fn.example/x", {
      method: "OPTIONS",
      headers: { Origin: web },
    }),
  );
  assertEquals(r.headers.get("Access-Control-Allow-Origin"), null);
});

Deno.test("parseOrigins rejects wildcards, null, paths and plain http", () => {
  const set = parseOrigins(
    `*, null, ${web}/, http://example.com, http://localhost:8099, ${web}, not a url`,
  );
  assertEquals([...set].sort(), [web, "http://localhost:8099"].sort());
});
