// 026 / Task 4: odgovor prolazi kroz lanac tekstualnih provajdera.
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import { createGenerator, GenerateError } from "./generate.ts";

function fakeFetch(handler: (url: string, init: RequestInit) => Response) {
  const calls: { url: string; init: RequestInit }[] = [];
  const f = ((u: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(u), init: init ?? {} });
    return Promise.resolve(handler(String(u), init ?? {}));
  }) as typeof fetch;
  return { f, calls };
}

const completion = (content: string) =>
  new Response(JSON.stringify({ choices: [{ message: { content } }] }));
const geminiOnly = (name: string) =>
  name === "GEMINI_API_KEY" ? "SECRET" : undefined;

Deno.test("ključ je u zaglavlju, pravila su odvojena i traži se JSON", async () => {
  const { f, calls } = fakeFetch(() => completion('{"answer":"x","used":[1]}'));
  const gen = createGenerator({ env: geminiOnly, fetch: f });
  const out = await gen("PRAVILA", "ODLOMCI i PITANJE");
  assertEquals(out, '{"answer":"x","used":[1]}');
  assert(!calls[0].url.includes("SECRET"));
  assertEquals(
    (calls[0].init.headers as Record<string, string>).Authorization,
    "Bearer SECRET",
  );
  const body = JSON.parse(String(calls[0].init.body));
  assertEquals(body.messages, [
    { role: "system", content: "PRAVILA" },
    { role: "user", content: "ODLOMCI i PITANJE" },
  ]);
  assertEquals(body.response_format.type, "json_object");
});

Deno.test("iscrpljen provajder prelazi na sledeći u tekstualnom lancu", async () => {
  const env = (name: string) => ({
    OPENAI_API_KEY: "OPENAI",
    OPENAI_MODEL: "gpt-test",
    AI_OPENAI_ENABLED: "1",
    GEMINI_API_KEY: "GEMINI",
  }[name]);
  const { f, calls } = fakeFetch((url) =>
    url.includes("api.openai.com")
      ? new Response("provider down", { status: 429 })
      : completion('{"answer":"odgovor","used":[1]}')
  );
  const out = await createGenerator({ env, fetch: f })("s", "p");
  assertEquals(JSON.parse(out).answer, "odgovor");
  assertEquals(calls.length, 2);
  assert(calls[0].url.includes("api.openai.com"));
  assert(calls[1].url.includes("generativelanguage.googleapis.com"));
});

Deno.test("ne otkriva telo greške kad se lanac iscrpi", async () => {
  const { f } = fakeFetch(() =>
    new Response("tajni tekst knjige", { status: 500 })
  );
  const err = await assertRejects(
    () => createGenerator({ env: geminiOnly, fetch: f })("s", "p"),
    GenerateError,
  );
  assertEquals(err.status, 500);
  assert(!err.message.includes("tajni"));
});

Deno.test("bez dostupnog ključa nema provider poziva", async () => {
  let called = false;
  const f = (() => {
    called = true;
    return Promise.resolve(completion("x"));
  }) as typeof fetch;
  await assertRejects(
    () => createGenerator({ env: () => undefined, fetch: f })("s", "p"),
    GenerateError,
  );
  assertEquals(called, false);
});
