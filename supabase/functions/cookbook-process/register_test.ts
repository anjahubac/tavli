// 026 / Task 3: registracija po putanji, sadržaju i vlasništvu.
import { assertEquals } from "jsr:@std/assert@1";

import {
  DuplicateBookError,
  LimitReachedError,
  MAX_BOOKS_PER_HOUSEHOLD,
  registerBook,
  type RegisterDeps,
} from "./register.ts";

const HH_A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const HH_B = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const USER = "11111111-1111-4111-8111-111111111111";
const FILE1 = "11111111-1111-4111-8111-111111111111";
const FILE2 = "22222222-2222-4222-8222-222222222222";

function deps(over: Partial<RegisterDeps> = {}) {
  const created: Parameters<RegisterDeps["createBook"]>[0][] = [];
  const removed: string[] = [];
  const contents = new Map<string, Uint8Array>();
  const hashes = new Set<string>();
  const d: RegisterDeps = {
    isMember: async (_u, hh) => hh === HH_A,
    objectExists: async () => true,
    readObject: async (path) =>
      contents.get(path) ?? new TextEncoder().encode("same book"),
    deleteObject: async (path) => {
      removed.push(path);
    },
    countBooks: async () => created.length,
    findByPath: async (_hh, path) => {
      const row = created.find((b) => b.path === path);
      return row ? { id: "new-id", status: "uploaded" } : null;
    },
    findByHash: async (_hh, hash) => hashes.has(hash),
    embeddingModel: "gemini-embedding-001",
    createBook: async (b) => {
      if (hashes.has(b.contentSha256)) throw new DuplicateBookError();
      created.push(b);
      hashes.add(b.contentSha256);
      return { id: "new-id", status: "uploaded" };
    },
    ...over,
  };
  return { d, created, removed, contents };
}

const request = (fileId = FILE1, filename = "Sarma.pdf", title = "Sarma") => ({
  storagePath: `${HH_A}/${fileId}.${filename.split(".").pop()}`,
  filename,
  title,
});

Deno.test("član svog domaćinstva registruje knjigu i čuva originalno ime", async () => {
  const { d, created } = deps();
  const r = await registerBook(d, USER, request());
  assertEquals(r, { ok: true, id: "new-id", status: "uploaded" });
  assertEquals(created[0].householdId, HH_A);
  assertEquals(created[0].filename, "Sarma.pdf");
  assertEquals(created[0].embeddingModel, "gemini-embedding-001");
  assertEquals(created[0].contentSha256.length, 64);
});

Deno.test("putanja tuđeg domaćinstva je forbidden", async () => {
  const { d, created } = deps();
  const r = await registerBook(d, USER, {
    storagePath: `${HH_B}/${FILE1}.pdf`,
    filename: "Sarma.pdf",
    title: "Sarma",
  });
  assertEquals(r, { ok: false, error: "forbidden" });
  assertEquals(created.length, 0);
});

Deno.test("putanja mora sadržati UUID i podržanu ekstenziju", async () => {
  let asked = false;
  const { d } = deps({
    isMember: async () => {
      asked = true;
      return true;
    },
  });
  for (
    const storagePath of [
      "nema-domacinstva.pdf",
      `${HH_A}/../${HH_B}/${FILE1}.pdf`,
      `${HH_A}/folder/${FILE1}.pdf`,
      `${HH_A}/staro-ime.pdf`,
      `${HH_A}/${FILE1}.docx`,
    ]
  ) {
    assertEquals(
      await registerBook(d, USER, {
        storagePath,
        filename: "Sarma.pdf",
        title: "Sarma",
      }),
      { ok: false, error: "bad_request" },
    );
  }
  assertEquals(asked, false);
});

Deno.test("duplikat sadržaja se odbija i briše novi upload", async () => {
  const { d, removed, created } = deps({ findByHash: async () => true });
  const req = request(FILE2, "Druga.pdf", "Druga");
  const r = await registerBook(d, USER, req);
  assertEquals(r, { ok: false, error: "duplicate" });
  assertEquals(removed, [req.storagePath]);
  assertEquals(created.length, 0);
});

Deno.test("ista knjiga pod različitim imenima ulazi samo jednom", async () => {
  const { d, created, removed } = deps();
  assertEquals(await registerBook(d, USER, request(FILE1, "Sarma.pdf")), {
    ok: true,
    id: "new-id",
    status: "uploaded",
  });
  const second = request(FILE2, "Porodicni recept.pdf", "Porodicni recept");
  assertEquals(await registerBook(d, USER, second), {
    ok: false,
    error: "duplicate",
  });
  assertEquals(created.length, 1);
  assertEquals(removed, [second.storagePath]);
});

Deno.test("različit sadržaj sa istim imenom su dve knjige", async () => {
  const { d, created, contents } = deps();
  contents.set(request(FILE1).storagePath, new TextEncoder().encode("sarma"));
  contents.set(request(FILE2).storagePath, new TextEncoder().encode("pasulj"));
  assertEquals((await registerBook(d, USER, request(FILE1))).ok, true);
  assertEquals((await registerBook(d, USER, request(FILE2))).ok, true);
  assertEquals(created.length, 2);
  assertEquals(created.map((b) => b.filename), ["Sarma.pdf", "Sarma.pdf"]);
});

Deno.test("limit knjiga po domaćinstvu: limit_reached", async () => {
  const { d } = deps({ countBooks: async () => MAX_BOOKS_PER_HOUSEHOLD });
  assertEquals(await registerBook(d, USER, request()), {
    ok: false,
    error: "limit_reached",
  });
});

Deno.test("ponovna registracija iste putanje vraća postojeću knjigu", async () => {
  const { d, created } = deps({
    findByPath: async () => ({ id: "old-id", status: "processing" }),
  });
  assertEquals(await registerBook(d, USER, request()), {
    ok: true,
    id: "old-id",
    status: "processing",
  });
  assertEquals(created.length, 0);
});

Deno.test("trka za limit i hash se mapira na jasnu grešku", async () => {
  const { d: limitDeps } = deps({
    createBook: async () => {
      throw new LimitReachedError();
    },
  });
  assertEquals(await registerBook(limitDeps, USER, request()), {
    ok: false,
    error: "limit_reached",
  });
  const { d: duplicateDeps } = deps({
    createBook: async () => {
      throw new DuplicateBookError();
    },
  });
  assertEquals(await registerBook(duplicateDeps, USER, request()), {
    ok: false,
    error: "duplicate",
  });
});
