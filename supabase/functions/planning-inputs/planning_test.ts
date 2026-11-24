import {
  type AdvisoryRequest,
  maxRecipeIds,
  minuteLimiter,
  type PlanningDependencies,
  planningInputs,
  tasteFoodIds,
} from "./planning.ts";

const household = "11111111-1111-4111-8111-111111111111";
const other = "22222222-2222-4222-8222-222222222222";
const fish = "33333333-3333-4333-8333-333333333333";

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      "Actual: " + JSON.stringify(actual) + "; expected: " +
        JSON.stringify(expected),
    );
  }
}

const emptyTastes = {
  likedFoodIds: [],
  dislikedFoodIds: [],
  likedDishKinds: [],
  dislikedDishKinds: [],
  likedCuisineCodes: [],
  dislikedCuisineCodes: [],
  favoriteRecipeCounts: {},
};

function setup(over: Partial<PlanningDependencies> = {}) {
  const advisory: AdvisoryRequest[] = [];
  const handle = planningInputs({
    authenticate: (token) =>
      Promise.resolve(token === "test-session" ? "user-a" : null),
    householdOf: () => Promise.resolve(household),
    membersOf: () => Promise.resolve(["user-a", "user-b"]),
    visibleTasteFoods: () => Promise.resolve([fish]),
    advisory: (request) => {
      advisory.push(request);
      return Promise.resolve({
        ...emptyTastes,
        dislikedFoodIds: [fish],
        likedCuisineCodes: ["italian"],
        favoriteRecipeCounts: { "recipe-1": 2 },
        extra: "dropped",
      });
    },
    allergenUnion: () => Promise.resolve([]),
    recipes: () => Promise.resolve([]),
    foods: () => Promise.resolve([]),
    allow: () => true,
    ...over,
  });
  return { handle, advisory };
}

function post(body: unknown, token = "test-session") {
  return new Request("http://local/planning-inputs", {
    method: "POST",
    headers: { Authorization: "Bearer " + token },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

Deno.test("returns the six taste arrays and favorite counts", async () => {
  const { handle, advisory } = setup();
  const response = await handle(post({ householdId: household }));
  equal(response.status, 200);
  equal(response.headers.get("Cache-Control"), "no-store");
  equal(await response.json(), {
    ...emptyTastes,
    dislikedFoodIds: [fish],
    likedCuisineCodes: ["italian"],
    favoriteRecipeCounts: { "recipe-1": 2 },
  });
  // Server bira učesnike (svi članovi) i listu namirnica.
  equal(advisory, [{
    actor: "user-a",
    household,
    participants: ["user-a", "user-b"],
    visibleFoodIds: [fish],
  }]);
});

Deno.test("rejects a missing or invalid session", async () => {
  const { handle, advisory } = setup();
  const noToken = new Request("http://local", {
    method: "POST",
    body: JSON.stringify({ householdId: household }),
  });
  equal((await handle(noToken)).status, 401);
  equal((await handle(post({ householdId: household }, "forged"))).status, 401);
  equal(advisory.length, 0);
});

Deno.test("rejects other methods", async () => {
  const { handle } = setup();
  const response = await handle(
    new Request("http://local", {
      method: "GET",
      headers: { Authorization: "Bearer test-session" },
    }),
  );
  equal(response.status, 405);
});

Deno.test("rejects a malformed body before any read", async () => {
  const reads: string[] = [];
  const { handle } = setup({
    householdOf: () => {
      reads.push("household");
      return Promise.resolve(household);
    },
  });
  for (
    const body of [
      "not json",
      [],
      {},
      { householdId: "not-a-uuid" },
      { householdId: household, participantIds: ["user-b"] },
      { householdId: household, padding: "x".repeat(2000) },
    ]
  ) {
    equal((await handle(post(body))).status, 400);
  }
  equal(reads, []);
});

Deno.test("a changed household stops the request", async () => {
  const { handle, advisory } = setup();
  equal((await handle(post({ householdId: other }))).status, 409);
  const left = setup({ householdOf: () => Promise.resolve(null) });
  equal((await left.handle(post({ householdId: household }))).status, 409);
  const removed = setup({ membersOf: () => Promise.resolve(["user-b"]) });
  equal((await removed.handle(post({ householdId: household }))).status, 409);
  equal(advisory.length + left.advisory.length + removed.advisory.length, 0);
});

Deno.test("an unexpected RPC shape is an internal error, not data", async () => {
  for (
    const shape of [
      null,
      { ...emptyTastes, likedFoodIds: "fish" },
      { ...emptyTastes, dislikedCuisineCodes: [1] },
      { likedFoodIds: [] },
      { ...emptyTastes, favoriteRecipeCounts: [] },
      { ...emptyTastes, favoriteRecipeCounts: { "recipe-1": 0 } },
      { ...emptyTastes, favoriteRecipeCounts: { "recipe-1": 1.5 } },
      { ...emptyTastes, favoriteRecipeCounts: { ["x".repeat(65)]: 1 } },
    ]
  ) {
    const { handle } = setup({ advisory: () => Promise.resolve(shape) });
    const response = await handle(post({ householdId: household }));
    equal(response.status, 500);
    equal(await response.json(), { error: "internal" });
  }
});

Deno.test("a failed read is an internal error without details", async () => {
  const { handle } = setup({
    membersOf: () => Promise.reject(new Error("db down: secret detail")),
  });
  const response = await handle(post({ householdId: household }));
  equal(response.status, 500);
  equal(await response.json(), { error: "internal" });
});

Deno.test("over the limit returns 429 before any read", async () => {
  const { handle, advisory } = setup({ allow: () => false });
  equal((await handle(post({ householdId: household }))).status, 429);
  equal(advisory.length, 0);
});

Deno.test("minute limiter counts per user and resets each minute", () => {
  let now = 0;
  const allow = minuteLimiter(2, () => now);
  equal([allow("a"), allow("a"), allow("a"), allow("b")], [
    true,
    true,
    false,
    true,
  ]);
  now = 60_000;
  equal(allow("a"), true);
});

Deno.test("taste food ids: only valid uuids from like and dislike lists", () => {
  equal(
    tasteFoodIds([
      { likedFoodIds: [fish, "bad"], dislikedFoodIds: [fish], other: [other] },
      null,
      { dislikedFoodIds: "nope" },
      { likedFoodIds: [household] },
    ]),
    [household, fish].sort(),
  );
});

// --- Bezbednost recepata za plan (TRELLO-43) ---

const peanut = "44444444-4444-4444-8444-444444444444";
const salt = "55555555-5555-4555-8555-555555555555";
const reviewedAt = "2026-11-24T00:00:00Z";

function food(id: string, codes: string[] | null) {
  return {
    id,
    household_id: null,
    withdrawn_at: null,
    allergen_codes: codes,
    allergen_reviewed_at: codes === null ? null : reviewedAt,
  };
}

const linked = (name: string, foodId: string) => ({
  name,
  quantity: 1,
  unit: "kom",
  foodId,
  matchedKey: name,
  linkSource: "confirmed",
});

const libraryRows = [
  { id: "safe", ingredients: [linked("so", salt)] },
  {
    id: "satay",
    ingredients: [linked("kikiriki", peanut), linked("so", salt)],
  },
  { id: "unlinked", ingredients: [{ name: "voda", quantity: 1 }] },
  { id: "not-asked", ingredients: [linked("so", salt)] },
];

function safetySetup(union: unknown, over: Partial<PlanningDependencies> = {}) {
  const reads: string[] = [];
  const result = setup({
    allergenUnion: (request) => {
      reads.push("union:" + request.participants.join(","));
      return Promise.resolve(union);
    },
    recipes: (_household, ids) => {
      reads.push("recipes:" + ids.join(","));
      return Promise.resolve(libraryRows);
    },
    foods: (ids) => {
      reads.push("foods:" + ids.join(","));
      return Promise.resolve([food(salt, []), food(peanut, ["peanuts"])]);
    },
    ...over,
  });
  return { ...result, reads };
}

const ask = (recipeIds: unknown) => post({ householdId: household, recipeIds });

Deno.test("without household allergens the plan is unrestricted", async () => {
  const { handle, reads, advisory } = safetySetup([]);
  const response = await handle(ask(["safe", "satay"]));
  equal(response.status, 200);
  equal(await response.json(), { restricted: false });
  // Samo unija svih članova; recepti i ukusi se ne čitaju.
  equal(reads, ["union:user-a,user-b"]);
  equal(advisory.length, 0);
});

Deno.test("with allergens only fully known safe recipes pass", async () => {
  const { handle, reads } = safetySetup(["peanuts", "milk"]);
  const response = await handle(ask(["unlinked", "satay", "safe", "safe"]));
  equal(response.status, 200);
  const text = await response.text();
  equal(JSON.parse(text), { restricted: true, safeRecipeIds: ["safe"] });
  // Odgovor ne nosi alergene ni članove.
  for (const leak of ["peanuts", "milk", "user-a", "user-b"]) {
    equal(text.includes(leak), false);
  }
  equal(reads, [
    "union:user-a,user-b",
    "recipes:safe,satay,unlinked",
    `foods:${[peanut, salt].sort().join(",")}`,
  ]);
});

Deno.test("recipe ids in an unexpected form are never safe", async () => {
  const { handle, reads } = safetySetup(["peanuts"]);
  const response = await handle(ask(["safe", "bad id", 'x",y', "é"]));
  equal(await response.json(), { restricted: true, safeRecipeIds: ["safe"] });
  equal(reads[1], "recipes:safe");
});

Deno.test("a malformed recipe list is rejected before any read", async () => {
  const { handle, reads } = safetySetup(["peanuts"]);
  for (
    const body of [
      { householdId: household, recipeIds: "safe" },
      { householdId: household, recipeIds: [1] },
      { householdId: household, recipeIds: [], extra: true },
      {
        householdId: household,
        recipeIds: Array.from({ length: maxRecipeIds + 1 }, (_, i) => `r${i}`),
      },
    ]
  ) {
    equal((await handle(post(body))).status, 400);
  }
  equal(reads, []);
});

Deno.test("an unknown allergen code fails closed", async () => {
  const { handle } = safetySetup(["peanuts", "unicorn"]);
  const response = await handle(ask(["safe"]));
  equal(response.status, 500);
  equal(await response.json(), { error: "internal" });
});

Deno.test("a changed household stops the safety check", async () => {
  const { handle, reads } = safetySetup(["peanuts"]);
  equal(
    (await handle(post({ householdId: other, recipeIds: ["safe"] }))).status,
    409,
  );
  equal(reads, []);
});
