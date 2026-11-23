// 026 / Task 3: klijent za embedding (lažni fetch, bez mreže).
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import { createEmbedder, EmbedError, EmbedQuotaError } from "./embed.ts";

function vec(n = 768) {
  return new Array(n).fill(0.5);
}

function fakeFetch(
  handler: (url: string, init: RequestInit) => Response | Promise<Response>,
) {
  const calls: { url: string; init: RequestInit }[] = [];
  const f = ((input: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(input), init: init ?? {} });
    return Promise.resolve(handler(String(input), init ?? {}));
  }) as typeof fetch;
  return { f, calls };
}

const ok = (n: number) =>
  new Response(
    JSON.stringify({
      embeddings: Array.from({ length: n }, () => ({ values: vec() })),
    }),
    {
      status: 200,
    },
  );

Deno.test("ključ ide u zaglavlje, nikad u URL; traži se 768 dimenzija", async () => {
  const { f, calls } = fakeFetch(() => ok(2));
  const embed = createEmbedder({ apiKey: "SECRET-KEY", fetch: f });
  const out = await embed(["a", "b"], "document");
  assertEquals(out.length, 2);
  assertEquals(out[0].length, 768);
  assert(!calls[0].url.includes("SECRET-KEY"));
  assertEquals(
    (calls[0].init.headers as Record<string, string>)["x-goog-api-key"],
    "SECRET-KEY",
  );
  const body = JSON.parse(String(calls[0].init.body));
  assertEquals(body.requests.length, 2);
  assertEquals(body.requests[0].outputDimensionality, 768);
  assertEquals(body.requests[0].taskType, "RETRIEVAL_DOCUMENT");
});

Deno.test("pitanje koristi RETRIEVAL_QUERY", async () => {
  const { f, calls } = fakeFetch((_url, init) =>
    ok(JSON.parse(String(init.body)).requests.length)
  );
  await createEmbedder({ apiKey: "k", fetch: f })(
    ["kako se kuva sarma"],
    "query",
  );
  assertEquals(
    JSON.parse(String(calls[0].init.body)).requests[0].taskType,
    "RETRIEVAL_QUERY",
  );
});

Deno.test("više od 100 tekstova ide u više poziva, redosled se čuva", async () => {
  let call = 0;
  const { f, calls } = fakeFetch((_u, init) => {
    const n = JSON.parse(String(init.body)).requests.length;
    call++;
    return new Response(
      JSON.stringify({
        embeddings: Array.from(
          { length: n },
          () => ({ values: new Array(768).fill(call) }),
        ),
      }),
    );
  });
  const out = await createEmbedder({ apiKey: "k", fetch: f })(
    Array.from({ length: 150 }, (_, i) => `t${i}`),
    "document",
  );
  assertEquals(out.length, 150);
  assertEquals(calls.length, 2);
  assertEquals(out[0][0], 1);
  assertEquals(out[149][0], 2);
});

Deno.test("greška provajdera se ne otkriva: kod statusa bez tela", async () => {
  const { f } = fakeFetch(() =>
    new Response('{"error":"tajni detalji korisnikovog teksta"}', {
      status: 429,
    })
  );
  const err = await assertRejects(
    () => createEmbedder({ apiKey: "k", fetch: f })(["x"], "document"),
    EmbedError,
  );
  assertEquals(err.status, 429);
  assert(!err.message.includes("tajni"));
});

Deno.test("neočekivan oblik odgovora je greška, ne tihi prazan rezultat", async () => {
  const { f } = fakeFetch(() =>
    new Response(JSON.stringify({ embeddings: [{ values: [1, 2] }] }))
  );
  // dužina vektora se proverava u processBook; ovde broj odgovora mora da se poklopi
  const { f: f2 } = fakeFetch(() =>
    new Response(JSON.stringify({ embeddings: [] }))
  );
  await assertRejects(
    () => createEmbedder({ apiKey: "k", fetch: f2 })(["a"], "document"),
    EmbedError,
  );
  const out = await createEmbedder({ apiKey: "k", fetch: f })(
    ["a"],
    "document",
  );
  assertEquals(out[0].length, 2);
});

Deno.test("bez ključa: greška pre bilo kakvog poziva", async () => {
  let called = false;
  const { f } = fakeFetch(() => {
    called = true;
    return ok(1);
  });
  await assertRejects(
    () => createEmbedder({ apiKey: "", fetch: f })(["a"], "document"),
    EmbedError,
  );
  assertEquals(called, false);
});

Deno.test("prazan niz ne zove provajdera", async () => {
  let called = false;
  const { f } = fakeFetch(() => {
    called = true;
    return ok(0);
  });
  assertEquals(
    await createEmbedder({ apiKey: "k", fetch: f })([], "document"),
    [],
  );
  assertEquals(called, false);
});

Deno.test("rezerviše kvotu pre svakog embedding batch-a", async () => {
  let reserved = 0;
  let released = 0;
  const { f, calls } = fakeFetch((_url, init) =>
    ok(JSON.parse(String(init.body)).requests.length)
  );
  const embed = createEmbedder({
    apiKey: "k",
    fetch: f,
    reserveBatch: async (userId) => {
      assertEquals(userId, "user-1");
      reserved++;
      return async () => {
        released++;
      };
    },
  });
  await embed(
    Array.from({ length: 101 }, (_, i) => `t${i}`),
    "document",
    "user-1",
  );
  assertEquals([reserved, released, calls.length], [2, 2, 2]);
});

Deno.test("odbijena kvota sprečava poziv embedding provajderu", async () => {
  let called = false;
  const { f } = fakeFetch(() => {
    called = true;
    return ok(1);
  });
  await assertRejects(
    () =>
      createEmbedder({
        apiKey: "k",
        fetch: f,
        reserveBatch: async () => {
          throw new EmbedQuotaError(60);
        },
      })(["tekst"], "document", "user-1"),
    EmbedQuotaError,
  );
  assertEquals(called, false);
});

Deno.test("model se bira iz podešavanja", async () => {
  const { f, calls } = fakeFetch(() => ok(1));
  await createEmbedder({ apiKey: "k", model: "neki-model", fetch: f })(
    ["a"],
    "document",
  );
  assert(calls[0].url.includes("models/neki-model:batchEmbedContents"));
});
