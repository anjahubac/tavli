// 026 / Task 3: obrada knjige u koracima koji mogu da se nastave, sa lažnim
// zavisnostima (bez mreže, baze i pravog PDF-a).
import { assert, assertEquals } from "jsr:@std/assert@1";

import { ExtractError } from "./extract.ts";
import {
  type Book,
  type ChunkRow,
  EMBEDDING_DIMENSIONS,
  MAX_CHUNKS_PER_PAGE,
  MAX_FILE_BYTES,
  type ProcessDeps,
  processBook,
} from "./process.ts";

const HH = "11111111-1111-4111-8111-111111111111";

function vec(): number[] {
  return new Array(EMBEDDING_DIMENSIONS).fill(0.01);
}

function fixture(opts: {
  pages?: string[];
  filename?: string;
  bytes?: number;
  extractError?: ExtractError;
  embedFailAtCall?: number;
  embedDims?: number;
  clockStep?: number;
  book?: Partial<Book>;
} = {}) {
  const book: Book = {
    id: "b1",
    householdId: HH,
    storagePath: `${HH}/knjiga.pdf`,
    filename: opts.filename ?? "knjiga.pdf",
    status: "uploaded",
    nextPage: 1,
    pages: null,
    ...opts.book,
  };
  const rows: ChunkRow[] = [];
  const patches: Record<string, unknown>[] = [];
  let embedCalls = 0, downloads = 0, t = 0;
  const deps: ProcessDeps = {
    getBook: async () => book,
    download: async () => {
      downloads++;
      return new Uint8Array(opts.bytes ?? 100);
    },
    extract: async () => {
      if (opts.extractError) throw opts.extractError;
      return opts.pages ?? ["Prva strana o sarmi.", "Druga strana o pasulju.", "Treca strana."];
    },
    embed: async (texts) => {
      embedCalls++;
      if (opts.embedFailAtCall === embedCalls) throw new Error("provider down");
      const dims = opts.embedDims ?? EMBEDDING_DIMENSIONS;
      return texts.map(() => new Array(dims).fill(0.01));
    },
    insertChunks: async (r) => {
      for (const row of r) {
        // idempotentno: isti (knjiga, stranica, indeks) se ne upisuje dvaput
        const exists = rows.some((x) =>
          x.cookbookId === row.cookbookId && x.page === row.page &&
          x.chunkIndex === row.chunkIndex
        );
        if (!exists) rows.push(row);
      }
    },
    updateBook: async (_id, patch) => {
      patches.push(patch);
      Object.assign(book, patch);
    },
    now: () => (t += opts.clockStep ?? 0),
  };
  return { deps, book, rows, patches, calls: () => ({ embedCalls, downloads }) };
}

Deno.test("cela knjiga: ready, chunkovi nose stranicu i indeks, jedan embed po stranici", async () => {
  const f = fixture();
  const r = await processBook(f.deps, "b1");
  assertEquals(r, { status: "ready", nextPage: 4 });
  assertEquals(f.book.status, "ready");
  assertEquals(f.book.pages, 3);
  assertEquals(f.rows.map((x) => [x.page, x.chunkIndex]), [[1, 0], [2, 0], [3, 0]]);
  assert(f.rows.every((x) => x.householdId === HH && x.embedding.length === EMBEDDING_DIMENSIONS));
  assertEquals(f.calls().embedCalls, 3);
});

Deno.test("prekid usred obrade: partial, upisano ostaje, nastavak ne duplira", async () => {
  const f = fixture({ embedFailAtCall: 2 });
  const first = await processBook(f.deps, "b1");
  assertEquals(first, { status: "partial", nextPage: 2 });
  assertEquals(f.book.status, "processing");
  assertEquals(f.book.errorCode, "embed_failed");
  assertEquals(f.rows.length, 1);

  const second = await processBook(f.deps, "b1");
  assertEquals(second, { status: "ready", nextPage: 4 });
  assertEquals(f.rows.length, 3);
  assertEquals(new Set(f.rows.map((x) => `${x.page}:${x.chunkIndex}`)).size, 3);
  assertEquals(f.book.errorCode ?? null, null);
  // strana 1 se nije ponovo ugrađivala: 1 (uspeh) + 1 (pad) + 2 (nastavak)
  assertEquals(f.calls().embedCalls, 4);
});

Deno.test("knjiga bez teksta: failed no_text, nijedan chunk", async () => {
  const f = fixture({ extractError: new ExtractError("no_text") });
  assertEquals(await processBook(f.deps, "b1"), { status: "failed", nextPage: 1 });
  assertEquals(f.book.status, "failed");
  assertEquals(f.book.errorCode, "no_text");
  assertEquals(f.rows.length, 0);
});

Deno.test("oštećen i preobiman fajl: failed sa kodom", async () => {
  const corrupt = fixture({ extractError: new ExtractError("corrupt") });
  await processBook(corrupt.deps, "b1");
  assertEquals(corrupt.book.errorCode, "corrupt");

  const tooMany = fixture({ extractError: new ExtractError("too_many_pages") });
  await processBook(tooMany.deps, "b1");
  assertEquals(tooMany.book.errorCode, "too_many_pages");
});

Deno.test("fajl veći od granice se odbija pre izvlačenja teksta", async () => {
  const f = fixture({ bytes: MAX_FILE_BYTES + 1 });
  await processBook(f.deps, "b1");
  assertEquals(f.book.status, "failed");
  assertEquals(f.book.errorCode, "too_large");
  assertEquals(f.calls().embedCalls, 0);
});

Deno.test("nepodržana vrsta fajla: failed unsupported_type, bez preuzimanja", async () => {
  const f = fixture({ filename: "knjiga.docx" });
  await processBook(f.deps, "b1");
  assertEquals(f.book.errorCode, "unsupported_type");
  assertEquals(f.calls().downloads, 0);
});

Deno.test("pogrešna dimenzija vektora: failed embed_invalid, ništa se ne upisuje", async () => {
  const f = fixture({ embedDims: 12 });
  await processBook(f.deps, "b1");
  assertEquals(f.book.status, "failed");
  assertEquals(f.book.errorCode, "embed_invalid");
  assertEquals(f.rows.length, 0);
});

Deno.test("vremenski budžet: posle isteka vraća partial, sledeći poziv nastavlja", async () => {
  const f = fixture({ clockStep: 1000 });
  const first = await processBook(f.deps, "b1", { budgetMs: 1500 });
  assertEquals(first.status, "partial");
  assertEquals(first.nextPage, 3);
  const second = await processBook(f.deps, "b1", { budgetMs: 1_000_000 });
  assertEquals(second.status, "ready");
  assertEquals(f.rows.length, 3);
});

Deno.test("već gotova ili nepostojeća knjiga: nema preuzimanja ni troška", async () => {
  const done = fixture({ book: { status: "ready", nextPage: 4, pages: 3 } });
  assertEquals(await processBook(done.deps, "b1"), { status: "ready", nextPage: 4 });
  assertEquals(done.calls().downloads, 0);

  const f = fixture();
  f.deps.getBook = async () => null;
  assertEquals((await processBook(f.deps, "nema")).status, "failed");
});

Deno.test("prazna stranica napreduje brojač bez poziva embeddinga", async () => {
  const f = fixture({ pages: ["Prva", "   ", "Treca"] });
  assertEquals((await processBook(f.deps, "b1")).status, "ready");
  assertEquals(f.rows.map((x) => x.page), [1, 3]);
  assertEquals(f.calls().embedCalls, 2);
});

Deno.test("stranica sa previše chunkova: failed too_large, bez embeddinga", async () => {
  const huge = "reč ".repeat(MAX_CHUNKS_PER_PAGE * 400);
  const f = fixture({ pages: ["Prva", huge] });
  const r = await processBook(f.deps, "b1");
  assertEquals(r.status, "failed");
  assertEquals(f.book.errorCode, "too_large");
  assertEquals(f.calls().embedCalls, 1);
});
