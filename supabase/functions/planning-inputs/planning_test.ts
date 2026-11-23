import {
  type AdvisoryRequest,
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
