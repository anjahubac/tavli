// Obrada jedne knjige u koracima koji mogu da se nastave (spec 026, FR-002):
// preuzmi fajl, izvuci tekst po stranici, podeli na chunkove, ugradi i upiši.
// Posle svake stranice `next_page` napreduje, a upis chunkova je idempotentan,
// pa ponovljen ili prekinut poziv ne pravi duplikate. Ne loguje sadržaj knjige.

import { chunkPage } from "./chunk.ts";
import { EMBEDDING_DIMENSIONS } from "./embed.ts";
import { ExtractError } from "./extract.ts";

export { EMBEDDING_DIMENSIONS };
export const MAX_FILE_BYTES = 15 * 1024 * 1024;
/** Jedna stranica sa više chunkova od ovoga je neispravna knjiga, ne posao za embedding. */
export const MAX_CHUNKS_PER_PAGE = 200;
/** Margina ispod limita Edge Function-a; posle nje poziv vraća `partial`. */
export const DEFAULT_BUDGET_MS = 100_000;

export interface Book {
  id: string;
  householdId: string;
  storagePath: string;
  filename: string;
  status: "uploaded" | "processing" | "ready" | "failed";
  nextPage: number;
  pages: number | null;
  errorCode?: string | null;
}

export interface ChunkRow {
  cookbookId: string;
  householdId: string;
  page: number;
  chunkIndex: number;
  content: string;
  embedding: number[];
}

export interface ProcessDeps {
  getBook: (id: string) => Promise<Book | null>;
  download: (storagePath: string) => Promise<Uint8Array>;
  /** Tekst po stranici; baca ExtractError za no_text, corrupt, too_many_pages. */
  extract: (filename: string, bytes: Uint8Array) => Promise<string[]>;
  embed: (texts: string[]) => Promise<number[][]>;
  /** Upis koji preskače već postojeće (knjiga, stranica, indeks). */
  insertChunks: (rows: ChunkRow[]) => Promise<void>;
  updateBook: (id: string, patch: Partial<Book>) => Promise<void>;
  now: () => number;
}

export interface ProcessResult {
  status: "ready" | "failed" | "partial";
  nextPage: number;
}

export async function processBook(
  deps: ProcessDeps,
  bookId: string,
  options: { budgetMs?: number } = {},
): Promise<ProcessResult> {
  const budgetMs = options.budgetMs ?? DEFAULT_BUDGET_MS;
  const book = await deps.getBook(bookId);
  if (!book) return { status: "failed", nextPage: 1 };
  if (book.status === "ready") return { status: "ready", nextPage: book.nextPage };
  if (book.status === "failed") return { status: "failed", nextPage: book.nextPage };

  const fail = async (code: string): Promise<ProcessResult> => {
    await deps.updateBook(book.id, { status: "failed", errorCode: code });
    return { status: "failed", nextPage: book.nextPage };
  };

  if (!/\.(pdf|epub)$/i.test(book.filename)) return fail("unsupported_type");

  const started = deps.now();
  await deps.updateBook(book.id, { status: "processing" });

  const bytes = await deps.download(book.storagePath);
  if (bytes.byteLength > MAX_FILE_BYTES) return fail("too_large");

  let pages: string[];
  try {
    pages = await deps.extract(book.filename, bytes);
  } catch (e) {
    return fail(e instanceof ExtractError ? e.code : "extract_failed");
  }
  await deps.updateBook(book.id, { pages: pages.length });

  const firstPage = book.nextPage;
  for (let n = firstPage; n <= pages.length; n++) {
    // Bar jedna stranica po pozivu, da obrada uvek napreduje.
    if (n > firstPage && deps.now() - started > budgetMs) {
      return { status: "partial", nextPage: n };
    }
    const chunks = chunkPage(pages[n - 1]);
    if (chunks.length > MAX_CHUNKS_PER_PAGE) return fail("too_large");
    if (chunks.length > 0) {
      let vectors: number[][];
      try {
        vectors = await deps.embed(chunks);
      } catch {
        await deps.updateBook(book.id, { status: "processing", errorCode: "embed_failed" });
        return { status: "partial", nextPage: n };
      }
      if (
        vectors.length !== chunks.length ||
        vectors.some((v) => v.length !== EMBEDDING_DIMENSIONS)
      ) {
        return fail("embed_invalid");
      }
      await deps.insertChunks(chunks.map((content, i) => ({
        cookbookId: book.id,
        householdId: book.householdId,
        page: n,
        chunkIndex: i,
        content,
        embedding: vectors[i],
      })));
    }
    await deps.updateBook(book.id, { nextPage: n + 1 });
  }

  await deps.updateBook(book.id, {
    status: "ready",
    nextPage: pages.length + 1,
    errorCode: null,
  });
  return { status: "ready", nextPage: pages.length + 1 };
}
