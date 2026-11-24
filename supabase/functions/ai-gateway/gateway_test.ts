import type { RankedRecipe } from "./recipe_vectors.ts";
import { gateway, type Reservation } from "./gateway.ts";
import { maxBodyBytes } from "./input.ts";

const textModel = "gemini/gemini-pro-latest";
const imageModel = "groq/qwen/qwen3.6-27b";
const typedRequest = {
  task: "recipe_from_name",
  model: textModel,
  system: "Return a JSON recipe.",
  prompt: "Beans.",
};
const png =
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jAfQAAAAASUVORK5CYII=";

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
  reservation = { id: "fake-reservation" },
  enableRecipeIndexing,
  rankRecipes,
  canSearchRecipes = () => Promise.resolve(true),
  upstream = () => Response.json({ choices: [{ message: { content: "{}" } }] }),
}: {
  env?: Record<string, string>;
  reservation?: Reservation;
  upstream?: () => Response;
  enableRecipeIndexing?: (
    token: string,
    householdId: string,
  ) => Promise<boolean>;
  rankRecipes?: (
    token: string,
    vector: number[],
    ids: string[],
  ) => Promise<RankedRecipe[]>;
  canSearchRecipes?: (token: string) => Promise<boolean>;
} = {}) {
  const reserved: unknown[] = [];
  const released: string[] = [];
  const calls: { url: string; init: RequestInit | undefined }[] = [];
  const variables = {
    GEMINI_API_KEY: "fake-gemini",
    GROQ_API_KEY: "fake-groq",
    ...env,
  };
  const handle = gateway({
    env: (name) => (variables as Record<string, string>)[name],
    authenticate: (token) =>
      Promise.resolve(token === "test-session" ? "synthetic-user" : null),
    reserve: (uid, kind, limits) => {
      reserved.push({ uid, kind, limits });
      return Promise.resolve(reservation);
    },
    release: (id) => {
      released.push(id);
      return Promise.resolve();
    },
    enableRecipeIndexing,
    rankRecipes,
    canSearchRecipes,
    reserveImage: () => Promise.reject(new Error("unexpected")),
    storeImage: () => Promise.reject(new Error("unexpected")),
    send: (url: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: String(url), init });
      return Promise.resolve(upstream());
    },
  });
  return { handle, reserved, released, calls };
}

function post(body: unknown = typedRequest, token = "test-session") {
  return new Request("http://local.test/ai-gateway", {
    method: "POST",
    headers: { Authorization: "Bearer " + token },
    body: JSON.stringify(body),
  });
}

Deno.test("uses only the verified user and reserves and releases one provider attempt", async () => {
  const { handle, reserved, released, calls } = setup();
  const result = await handle(post());
  equal(result.status, 200);
  equal(await result.json(), { content: "{}", model: textModel });
  equal(reserved, [{
    uid: "synthetic-user",
    kind: "text",
    limits: { daily: 150, minute: 20, concurrent: 2, global: 2000 },
  }]);
  equal(released, ["fake-reservation"]);
  equal(calls.length, 1);
  equal(
    calls[0].url,
    "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
  );
  equal(calls[0].init?.redirect, "error");
  equal(JSON.parse(String(calls[0].init?.body)).max_tokens, 4096);
});

Deno.test("rejects unauthorized, forged, invalid and oversized input before quota or provider work", async () => {
  const { handle, reserved, calls } = setup();
  equal((await handle(post(typedRequest, "invalid"))).status, 401);
  equal(
    (await handle(new Request("http://local.test/ai-gateway"))).status,
    401,
  );
  for (
    const extra of [
      { user_id: "forged" },
      { url: "http://local.test/other" },
      { model: "gemini/arbitrary" },
      { model: "constructor" },
      { images: [png] },
      {
        task: "recipe_from_image",
        model: imageModel,
        images: ["data:image/png;base64,YQ=="],
      },
    ]
  ) {
    equal((await handle(post({ ...typedRequest, ...extra }))).status, 400);
  }
  const tooLarge = await handle(
    post({ ...typedRequest, prompt: "a".repeat(maxBodyBytes) }),
  );
  equal(tooLarge.status, 413);
  equal(reserved.length, 0);
  equal(calls.length, 0);
});

Deno.test("daily and concurrency denials have typed errors and skip the provider", async () => {
  for (
    const [limit, body] of [
      ["daily", { error: "quota_exceeded", limit: "daily", kind: "text" }],
      ["concurrent", { error: "busy" }],
    ] as const
  ) {
    const { handle, calls, released } = setup({
      reservation: { limit, retryAfterSeconds: 45 },
    });
    const result = await handle(post());
    equal(result.status, 429);
    equal(await result.json(), { ...body, retryAfterSeconds: 45 });
    equal(calls.length, 0);
    equal(released.length, 0);
  }
});

Deno.test("a provider error returns only a typed error and releases the reservation", async () => {
  const { handle, calls, released } = setup({
    upstream: () =>
      new Response("private upstream error", {
        status: 429,
        headers: { "Retry-After": "15" },
      }),
  });
  const result = await handle(post());
  equal(result.status, 429);
  equal(await result.json(), {
    error: "provider_rate_limited",
    retryAfterSeconds: 15,
  });
  equal(calls.length, 1);
  equal(released, ["fake-reservation"]);
});

const recipe = {
  title: "Sarma",
  servings: 6,
  ingredients: [{ name: "kiseli kupus", quantity: 1, unit: "glavica" }],
  steps: ["Umotati sarme."],
};

function modelAnswer(content: unknown) {
  return () =>
    Response.json({
      choices: [{
        message: {
          content: typeof content === "string"
            ? content
            : JSON.stringify(content),
        },
      }],
    });
}

function photoRequest() {
  return post({
    ...typedRequest,
    task: "recipe_from_image",
    model: imageModel,
    images: [png],
  });
}

Deno.test("accepts image input and sends it to the allowlisted Groq vision model", async () => {
  const { handle, calls, reserved } = setup({ upstream: modelAnswer(recipe) });
  const result = await handle(post({
    ...typedRequest,
    task: "recipe_from_image",
    model: imageModel,
    images: [png],
  }));
  equal(result.status, 200);
  equal(calls[0].url, "https://api.groq.com/openai/v1/chat/completions");
  const request = JSON.parse(String(calls[0].init?.body));
  equal(request.model, "qwen/qwen3.6-27b");
  equal(request.max_completion_tokens, 4096);
  equal(request.messages[1].content[1].image_url.url, png);
  equal((reserved[0] as { kind: string }).kind, "vision");
});

Deno.test("lists only configured models and places opted-in OpenAI first for both kinds", async () => {
  const authGet = new Request("http://local.test/ai-gateway", {
    headers: { Authorization: "Bearer test-session" },
  });
  const credentials = {
    OPENAI_API_KEY: "fake-openai",
    OPENAI_MODEL: "fake-model",
  };
  const off = setup({ env: credentials });
  const before = await (await off.handle(authGet)).json();
  equal(before.text[0], textModel);
  equal(before.vision[0], "gemini/gemini-flash-latest");
  equal(
    (await off.handle(post({ ...typedRequest, model: "openai/default" })))
      .status,
    503,
  );
  equal(off.reserved.length, 0);

  const on = setup({ env: { ...credentials, AI_OPENAI_ENABLED: "1" } });
  const after = await (await on.handle(authGet)).json();
  equal(after.text, ["openai/default", ...before.text]);
  equal(after.vision, ["openai/default", ...before.vision]);
  equal(on.reserved.length, 0);
  equal(on.calls.length, 0);
  equal(
    (await on.handle(post({ ...typedRequest, model: "openai/default" })))
      .status,
    200,
  );
  const request = JSON.parse(String(on.calls[0].init?.body));
  equal(request.model, "fake-model");
  equal(request.reasoning_effort, "none");
  equal("temperature" in request, false);
});

Deno.test("only reasoning models get the lowest effort", async () => {
  const { handle, calls } = setup();
  equal((await handle(post())).status, 200);
  const request = JSON.parse(String(calls[0].init?.body));
  equal("reasoning_effort" in request, false);
});

Deno.test("the gateway kill switch skips both quota and provider", async () => {
  const { handle, reserved, calls } = setup({
    env: { AI_GATEWAY_DISABLED: "1" },
  });
  const result = await handle(post());
  equal(result.status, 503);
  equal(await result.json(), { error: "gateway_unavailable" });
  equal(reserved.length, 0);
  equal(calls.length, 0);
});

Deno.test("GET lists models in the AI_PROVIDER_ORDER order and warns about unknown names", async () => {
  const authGet = new Request("http://local.test/ai-gateway", {
    headers: { Authorization: "Bearer test-session" },
  });
  const warnings: string[] = [];
  const warn = console.warn;
  console.warn = (message: string) => warnings.push(message);
  try {
    const { handle, reserved, calls } = setup({
      env: {
        AI_PROVIDER_ORDER: "openai,gemini,groq,openrouter,open ai",
        OPENAI_API_KEY: "fake-openai",
        OPENAI_MODEL: "fake-model",
        AI_OPENAI_ENABLED: "1",
        OPENROUTER_API_KEY: "fake-openrouter",
      },
    });
    const body = await (await handle(authGet)).json();
    equal(body.text, [
      "openai/default",
      "gemini/gemini-pro-latest",
      "gemini/gemini-flash-latest",
      "gemini/gemini-flash-lite-latest",
      "groq/openai/gpt-oss-120b",
      "groq/llama-3.3-70b-versatile",
      "openrouter/google/gemma-3-27b-it:free",
    ]);
    equal(body.vision[0], "openai/default");
    equal(body.vision[1], "gemini/gemini-flash-latest");
    equal(warnings, ["ai_provider_order_ignored open ai"]);
    equal(reserved.length, 0);
    equal(calls.length, 0);
  } finally {
    console.warn = warn;
  }
});

Deno.test("each answered call logs only the model id and status", async () => {
  const lines: string[] = [];
  const info = console.info;
  console.info = (message: string) => lines.push(message);
  try {
    const { handle } = setup({ env: { AI_PROVIDER_ORDER: "groq,gemini" } });
    const result = await handle(post());
    equal(await result.json(), { content: "{}", model: textModel });
    equal(lines, ["ai_gateway_call model=" + textModel + " status=200"]);
  } finally {
    console.info = info;
  }
});

const recipeVectorEnv = {
  AI_RECIPE_VECTORS_ENABLED: "1",
  AI_RECIPE_VECTOR_ACCOUNT: "0".repeat(32),
  AI_RECIPE_VECTOR_TOKEN: "fake-workers-ai",
};

const recipeSearch = {
  task: "recipe_similarity_search",
  query: "nešto lagano za večeru",
  recipeIds: ["own-recipe", "own-recipe"],
};

Deno.test("server recipe search rejects candidates beyond the SQL limit", async () => {
  const search = setup({
    env: recipeVectorEnv,
    rankRecipes: () => Promise.resolve([]),
  });
  const result = await search.handle(post({
    ...recipeSearch,
    recipeIds: Array.from({ length: 257 }, (_, i) => `recipe-${i}`),
  }));
  equal(result.status, 400);
  equal(search.calls.length, 0);
  equal(search.reserved.length, 0);
});

Deno.test("server recipe search embeds the query and ranks as the caller", async () => {
  const vector = Array<number>(1024).fill(0.25);
  const matches = [{ recipe_id: "own-recipe", distance: 0.125 }];
  const search = setup({
    env: recipeVectorEnv,
    upstream: () => Response.json({ data: [{ index: 0, embedding: vector }] }),
    rankRecipes: (token, embedding, ids) => {
      equal(token, "test-session");
      equal(embedding, vector);
      equal(ids, ["own-recipe"]);
      return Promise.resolve(matches);
    },
  });
  const result = await search.handle(post(recipeSearch));
  equal(result.status, 200);
  equal(await result.json(), { matches });
  equal(search.calls.length, 1);
  const body = JSON.parse(String(search.calls[0].init?.body));
  equal(
    search.calls[0].url,
    "https://api.cloudflare.com/client/v4/accounts/" + "0".repeat(32) +
      "/ai/v1/embeddings",
  );
  equal(body, { model: "@cf/baai/bge-m3", input: [recipeSearch.query] });
  equal(search.reserved.length, 1);
  equal(search.released, ["fake-reservation"]);
});

Deno.test("disabled, unauthorized, malformed and quota-denied search skip provider work", async () => {
  const rankRecipes = () => Promise.reject(new Error("unexpected SQL call"));
  const disabled = setup({ rankRecipes });
  equal((await disabled.handle(post(recipeSearch))).status, 503);
  const denied = setup({
    rankRecipes,
    env: recipeVectorEnv,
    reservation: { limit: "daily", retryAfterSeconds: 60 },
  });
  equal((await denied.handle(post(recipeSearch, "invalid"))).status, 401);
  equal(
    (await denied.handle(post({ ...recipeSearch, owner: "forged" }))).status,
    400,
  );
  equal((await denied.handle(post(recipeSearch))).status, 429);
  equal(denied.reserved.length, 1);
  equal(denied.calls.length, 0);
  equal(disabled.reserved.length, 0);
  equal(disabled.calls.length, 0);
});

Deno.test("search without household consent never reaches the provider", async () => {
  const checked: string[] = [];
  const search = setup({
    env: recipeVectorEnv,
    canSearchRecipes: (token) => {
      checked.push(token);
      return Promise.resolve(false);
    },
    rankRecipes: () => Promise.reject(new Error("unexpected SQL call")),
  });
  equal((await search.handle(post(recipeSearch))).status, 403);
  equal(checked, ["test-session"]);
  equal(search.calls.length, 0);
  equal(search.reserved.length, 0);
});

Deno.test("server search rejects a zero-length direction and releases quota", async () => {
  const search = setup({
    env: recipeVectorEnv,
    upstream: () =>
      Response.json({
        data: [{ index: 0, embedding: Array<number>(1024).fill(0) }],
      }),
    rankRecipes: () => Promise.reject(new Error("unexpected SQL call")),
  });
  equal((await search.handle(post(recipeSearch))).status, 502);
  equal(search.released, ["fake-reservation"]);
});

Deno.test("recipe indexing records consent as the caller without contacting the provider", async () => {
  const householdId = "10000000-0000-0000-0000-000000000001";
  const otherId = "10000000-0000-0000-0000-000000000002";
  const recorded: [string, string][] = [];
  const { handle, reserved, calls } = setup({
    env: recipeVectorEnv,
    enableRecipeIndexing: (token, id) => {
      recorded.push([token, id]);
      return Promise.resolve(id === householdId);
    },
  });
  const consent = { task: "recipe_vector_consent", householdId };
  equal((await handle(post(consent, "forged"))).status, 401);
  equal(
    (await handle(post({ ...consent, householdId: "invalid" }))).status,
    400,
  );
  equal((await handle(post({ ...consent, householdId: otherId }))).status, 403);
  const accepted = await handle(post(consent));
  equal(accepted.status, 200);
  equal(await accepted.json(), { enabled: true });
  equal(recorded, [["test-session", otherId], ["test-session", householdId]]);
  equal(reserved, []);
  equal(calls, []);
});

Deno.test("a photo import returns a valid recipe, a fenced one and not_a_recipe unchanged", async () => {
  for (
    const answer of [
      recipe,
      "```json\n" + JSON.stringify(recipe) + "\n```",
      { error: "not_a_recipe" },
      { ...recipe, steps: null },
    ]
  ) {
    const { handle } = setup({ upstream: modelAnswer(answer) });
    const result = await handle(photoRequest());
    equal(result.status, 200);
  }
});

Deno.test("a photo import that is not a valid recipe becomes invalid_model_output and releases quota", async () => {
  const bad: unknown[] = [
    "not json at all",
    "[]",
    {},
    { ...recipe, title: "   " },
    { ...recipe, servings: 0 },
    { ...recipe, servings: 2.5 },
    { ...recipe, servings: "4" },
    { ...recipe, ingredients: "kupus" },
    { ...recipe, ingredients: [] },
    { ...recipe, ingredients: [{ quantity: 1 }] },
    { ...recipe, ingredients: ["kupus"] },
    { ...recipe, steps: "Umotati." },
    { ...recipe, steps: [1, 2] },
    { error: "something_else" },
  ];
  for (const answer of bad) {
    const { handle, released } = setup({ upstream: modelAnswer(answer) });
    const result = await handle(photoRequest());
    equal(result.status, 502);
    equal(await result.json(), { error: "invalid_model_output" });
    equal(released, ["fake-reservation"]);
  }
});

Deno.test("the recipe output check applies only to the photo import", async () => {
  const { handle } = setup({ upstream: modelAnswer("{}") });
  const result = await handle(post());
  equal(result.status, 200);
});
