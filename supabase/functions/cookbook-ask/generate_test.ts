// 026 / Task 4: poziv modela za odgovor (lažni fetch).
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import { createGenerator, GenerateError } from "./generate.ts";

function fakeFetch(res: Response) {
  const calls: { url: string; init: RequestInit }[] = [];
  const f = ((u: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(u), init: init ?? {} });
    return Promise.resolve(res);
  }) as typeof fetch;
  return { f, calls };
}

const ok = (text: string) =>
  new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text }] } }] }));

Deno.test("ključ u zaglavlju, sistemska poruka odvojena od pitanja, JSON odgovor", async () => {
  const { f, calls } = fakeFetch(ok('{"answer":"x","used":[1]}'));
  const gen = createGenerator({ apiKey: "SECRET", fetch: f });
  const out = await gen("PRAVILA", "ODLOMCI i PITANJE");
  assertEquals(out, '{"answer":"x","used":[1]}');
  assert(!calls[0].url.includes("SECRET"));
  assertEquals((calls[0].init.headers as Record<string, string>)["x-goog-api-key"], "SECRET");
  const body = JSON.parse(String(calls[0].init.body));
  assertEquals(body.systemInstruction.parts[0].text, "PRAVILA");
  assertEquals(body.contents[0].parts[0].text, "ODLOMCI i PITANJE");
  assertEquals(body.generationConfig.responseMimeType, "application/json");
  assert(body.generationConfig.maxOutputTokens <= 1024);
});

Deno.test("greška provajdera nosi samo status, ne telo", async () => {
  const { f } = fakeFetch(new Response("tajni tekst knjige", { status: 500 }));
  const err = await assertRejects(() => createGenerator({ apiKey: "k", fetch: f })("s", "p"), GenerateError);
  assertEquals(err.status, 500);
  assert(!err.message.includes("tajni"));
});

Deno.test("odgovor bez teksta je greška, ne prazan niz", async () => {
  const { f } = fakeFetch(new Response(JSON.stringify({ candidates: [] })));
  await assertRejects(() => createGenerator({ apiKey: "k", fetch: f })("s", "p"), GenerateError);
});

Deno.test("bez ključa nema poziva", async () => {
  let called = false;
  const f = (() => { called = true; return Promise.resolve(ok("x")); }) as typeof fetch;
  await assertRejects(() => createGenerator({ apiKey: "", fetch: f })("s", "p"), GenerateError);
  assertEquals(called, false);
});
