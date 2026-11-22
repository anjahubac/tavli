// 026 / Task 3: registracija otpremljene knjige (autorizacija po putanji).
import { assertEquals } from "jsr:@std/assert@1";

import { LimitReachedError, MAX_BOOKS_PER_HOUSEHOLD, registerBook, type RegisterDeps } from "./register.ts";

const HH_A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const HH_B = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const USER = "uuuuuuuu-uuuu-4uuu-8uuu-uuuuuuuuuuuu".replaceAll("u", "1");

function deps(over: Partial<RegisterDeps> = {}) {
  const created: { householdId: string; path: string; title: string }[] = [];
  const d: RegisterDeps = {
    isMember: async (_u, hh) => hh === HH_A,
    objectExists: async () => true,
    countBooks: async () => 0,
    findByPath: async () => null,
    createBook: async (b) => {
      created.push(b);
      return { id: "new-id", status: "uploaded" };
    },
    ...over,
  };
  return { d, created };
}

Deno.test("član koji upisuje u svoje domaćinstvo: knjiga se pravi", async () => {
  const { d, created } = deps();
  const r = await registerBook(d, USER, { storagePath: `${HH_A}/sarma.pdf`, title: "Sarma" });
  assertEquals(r, { ok: true, id: "new-id", status: "uploaded" });
  assertEquals(created[0].householdId, HH_A);
});

Deno.test("putanja tuđeg domaćinstva: forbidden, ništa se ne pravi", async () => {
  const { d, created } = deps();
  const r = await registerBook(d, USER, { storagePath: `${HH_B}/tudja.pdf`, title: "x" });
  assertEquals(r, { ok: false, error: "forbidden" });
  assertEquals(created.length, 0);
});

Deno.test("neispravna putanja ili tip: bad_request pre provere članstva", async () => {
  let asked = false;
  const { d } = deps({ isMember: async () => { asked = true; return true; } });
  for (const p of ["nema-domacinstva.pdf", `${HH_A}/../${HH_B}/x.pdf`, `${HH_A}/a/b.pdf`, `${HH_A}/knjiga.docx`, `${HH_A}/`, "nije-uuid/x.pdf"]) {
    const r = await registerBook(d, USER, { storagePath: p, title: "t" });
    assertEquals(r, { ok: false, error: "bad_request" }, p);
  }
  assertEquals(asked, false);
});

Deno.test("naslov: prazan se menja imenom fajla, predug je bad_request", async () => {
  const { d, created } = deps();
  await registerBook(d, USER, { storagePath: `${HH_A}/Moja Knjiga.epub`, title: "   " });
  assertEquals(created[0].title, "Moja Knjiga");
  const r = await registerBook(d, USER, { storagePath: `${HH_A}/a.pdf`, title: "x".repeat(201) });
  assertEquals(r, { ok: false, error: "bad_request" });
});

Deno.test("objekat ne postoji u skladištu: not_found", async () => {
  const { d, created } = deps({ objectExists: async () => false });
  const r = await registerBook(d, USER, { storagePath: `${HH_A}/a.pdf`, title: "t" });
  assertEquals(r, { ok: false, error: "not_found" });
  assertEquals(created.length, 0);
});

Deno.test("limit knjiga po domaćinstvu: limit_reached", async () => {
  const { d } = deps({ countBooks: async () => MAX_BOOKS_PER_HOUSEHOLD });
  const r = await registerBook(d, USER, { storagePath: `${HH_A}/a.pdf`, title: "t" });
  assertEquals(r, { ok: false, error: "limit_reached" });
});

Deno.test("ponovna registracija iste putanje vraća postojeću knjigu", async () => {
  const { d, created } = deps({ findByPath: async () => ({ id: "old-id", status: "processing" }) });
  const r = await registerBook(d, USER, { storagePath: `${HH_A}/a.pdf`, title: "t" });
  assertEquals(r, { ok: true, id: "old-id", status: "processing" });
  assertEquals(created.length, 0);
});

Deno.test("baza odbija 21. knjigu u trci: limit_reached, ne greška servera", async () => {
  const { d } = deps({ createBook: async () => { throw new LimitReachedError(); } });
  const r = await registerBook(d, USER, { storagePath: `${HH_A}/a.pdf`, title: "t" });
  assertEquals(r, { ok: false, error: "limit_reached" });
});
