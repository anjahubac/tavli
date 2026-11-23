import { gateway } from "./gateway.ts";
import {
  cleanDescription,
  imageLimits,
  imagePrompt,
  type ImageReservation,
  imageStyle,
  maxDescriptionLength,
  parseImageRequest,
} from "./image.ts";

const household = "00000000-0000-4000-8000-0000000000aa";
const description =
  "One thick rope of rolled phyllo coiled into a flat snail spiral, whole " +
  "pie uncut, in a round black pan, top-down.";
// Najmanji JPEG oblik koji provera prihvata (SOI ... EOI).
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x00, 0xff, 0xd9]);

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      "Actual: " + JSON.stringify(actual) + "; expected: " +
        JSON.stringify(expected),
    );
  }
}

function setup({
  env = {},
  reservation = { id: "res", householdId: household },
  upstream = () => Response.json({ result: { image: jpeg.toBase64() } }),
}: {
  env?: Record<string, string>;
  reservation?: ImageReservation;
  upstream?: () => Response;
} = {}) {
  const reserved: unknown[] = [];
  const stored: { householdId: string; file: string; size: number }[] = [];
  const calls: { url: string; body: unknown; auth: string | null }[] = [];
  const variables: Record<string, string> = {
    AI_IMAGES_ENABLED: "1",
    CF_ACCOUNT_ID: "fakeaccount",
    CF_API_TOKEN: "fake-token",
    ...env,
  };
  const handle = gateway({
    env: (name) => variables[name],
    authenticate: (token) =>
      Promise.resolve(token === "test-session" ? "synthetic-user" : null),
    reserve: () => Promise.reject(new Error("unexpected")),
    release: () => Promise.resolve(),
    reserveImage: (uid, recipeId, limits) => {
      reserved.push({ uid, recipeId, limits });
      return Promise.resolve(reservation);
    },
    storeImage: (householdId, file, bytes) => {
      stored.push({ householdId, file, size: bytes.byteLength });
      return Promise.resolve();
    },
    send: (url: string | URL | Request, init?: RequestInit) => {
      calls.push({
        url: String(url),
        body: JSON.parse(String(init?.body)),
        auth: new Headers(init?.headers).get("Authorization"),
      });
      return Promise.resolve(upstream());
    },
  });
  return { handle, reserved, stored, calls };
}

function post(body: unknown, token = "test-session") {
  return new Request("http://local.test/ai-gateway", {
    method: "POST",
    headers: { Authorization: "Bearer " + token },
    body: JSON.stringify(body),
  });
}

const request = { task: "recipe_image", recipeId: "recipe-1", description };

Deno.test("prompt is the description plus the fixed style", () => {
  equal(imagePrompt(description), description + " " + imageStyle);
  equal(imagePrompt("Beans in a pot"), "Beans in a pot. " + imageStyle);
});

Deno.test("description is trimmed, flattened and capped", () => {
  equal(cleanDescription("  a\n\tb   c \u0007 "), "a b c");
  const long = "word ".repeat(400);
  equal(cleanDescription(long).length <= maxDescriptionLength, true);
});

Deno.test("parses only recipe id and description", () => {
  equal(parseImageRequest(request), {
    recipeId: "recipe-1",
    description,
  });
  for (
    const bad of [
      { ...request, model: "@cf/other" },
      { ...request, url: "https://example.test" },
      { ...request, recipeId: "../x" },
      { ...request, recipeId: "" },
      { ...request, description: 3 },
      { ...request, description: "short" },
      { task: "recipe_image", description },
    ]
  ) {
    equal(parseImageRequest(bad), undefined);
  }
});

Deno.test("limits default to 30 per user, 60 per project and 3 attempts", () => {
  equal(imageLimits(() => undefined), { user: 30, project: 60, attempts: 3 });
  equal(
    imageLimits((name) => name === "AI_IMAGES_DAILY_CAP" ? "15" : undefined)
      .project,
    15,
  );
  let threw = false;
  try {
    imageLimits((name) => name === "AI_IMAGES_DAILY_CAP" ? "0" : undefined);
  } catch {
    threw = true;
  }
  equal(threw, true);
});

Deno.test("generates with FLUX schnell, no width or height, and stores the JPEG", async () => {
  const { handle, reserved, stored, calls } = setup();
  const result = await handle(post(request));
  equal(result.status, 200);
  const body = await result.json();
  equal(/^ai_[0-9a-f-]{36}\.jpg$/.test(body.file), true);
  equal(body.path, household + "/" + body.file);
  equal(reserved, [{
    uid: "synthetic-user",
    recipeId: "recipe-1",
    limits: { user: 30, project: 60, attempts: 3 },
  }]);
  equal(calls.length, 1);
  equal(
    calls[0].url,
    "https://api.cloudflare.com/client/v4/accounts/fakeaccount/ai/run/@cf/black-forest-labs/flux-1-schnell",
  );
  equal(calls[0].auth, "Bearer fake-token");
  equal(calls[0].body, {
    prompt: description + " " + imageStyle,
    steps: 4,
  });
  equal(stored, [{ householdId: household, file: body.file, size: 8 }]);
});

Deno.test("the kill switch and missing credentials disable images before quota", async () => {
  for (
    const env of <Record<string, string>[]> [
      { AI_IMAGES_ENABLED: "0" },
      { CF_API_TOKEN: "" },
      { CF_ACCOUNT_ID: "../bad" },
    ]
  ) {
    const { handle, reserved, calls } = setup({ env });
    const result = await handle(post(request));
    equal(result.status, 503);
    equal(await result.json(), { error: "disabled" });
    equal(reserved.length, 0);
    equal(calls.length, 0);
  }
});

Deno.test("rejects unauthorized and bad input before quota", async () => {
  const { handle, reserved, calls } = setup();
  equal((await handle(post(request, "forged"))).status, 401);
  equal((await handle(post({ ...request, recipeId: "a/b" }))).status, 400);
  equal(
    (await handle(post({ ...request, description: "x".repeat(5000) }))).status,
    413,
  );
  equal(reserved.length, 0);
  equal(calls.length, 0);
});

Deno.test("user and project quota denials are typed and skip the provider", async () => {
  for (const limit of ["user", "project"] as const) {
    const { handle, calls, stored } = setup({
      reservation: { limit, retryAfterSeconds: 3600 },
    });
    const result = await handle(post(request));
    equal(result.status, 429);
    equal(await result.json(), {
      error: "quota_exceeded",
      limit,
      retryAfterSeconds: 3600,
    });
    equal(calls.length, 0);
    equal(stored.length, 0);
  }
});

Deno.test("a user without a household is forbidden", async () => {
  const { handle, calls } = setup({ reservation: { error: "no_household" } });
  const result = await handle(post(request));
  equal(result.status, 403);
  equal(calls.length, 0);
});

Deno.test("maps Cloudflare errors to typed errors without provider bodies", async () => {
  const cases: [() => Response, number, Record<string, unknown>][] = [
    [
      () =>
        new Response("secret detail", {
          status: 429,
          headers: { "Retry-After": "120" },
        }),
      429,
      { error: "rate_limited", retryAfterSeconds: 120 },
    ],
    [
      () => new Response("secret detail", { status: 429 }),
      429,
      { error: "rate_limited", retryAfterSeconds: 60 },
    ],
    [
      () => new Response("secret detail", { status: 500 }),
      502,
      { error: "provider_error" },
    ],
    [
      () => Response.json({ result: { image: "" } }),
      502,
      { error: "provider_error" },
    ],
    [
      () =>
        Response.json({
          result: { image: new Uint8Array([1, 2, 3, 4, 5]).toBase64() },
        }),
      502,
      { error: "provider_error" },
    ],
  ];
  for (const [upstream, status, body] of cases) {
    const { handle, stored } = setup({ upstream });
    const result = await handle(post(request));
    equal(result.status, status);
    equal(await result.json(), body);
    equal(stored.length, 0);
  }
});

Deno.test("a network failure is a typed provider error", async () => {
  const { handle } = setup({
    upstream: () => {
      throw new DOMException("timed out", "TimeoutError");
    },
  });
  // fetch baca pre isteka roka: to nije timeout.
  const result = await handle(post(request));
  equal(result.status, 502);
  equal(await result.json(), { error: "provider_error" });
});

Deno.test("an aborted provider call is a typed timeout", async () => {
  const original = AbortSignal.timeout;
  AbortSignal.timeout = () => AbortSignal.abort();
  try {
    const { handle, stored } = setup({
      upstream: () => {
        throw new DOMException("timed out", "TimeoutError");
      },
    });
    const result = await handle(post(request));
    equal(result.status, 504);
    equal(await result.json(), { error: "timeout" });
    equal(stored.length, 0);
  } finally {
    AbortSignal.timeout = original;
  }
});

Deno.test("the description task is allowlisted for text models", async () => {
  const { tasks } = await import("./input.ts");
  equal(tasks.get("recipe_image_description"), "text");
});
