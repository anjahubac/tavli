# Cookbook RAG Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A household member uploads a text PDF or EPUB cookbook, asks a question, and gets an answer with book and page, and can save a result as a recipe through the existing review flow.

**Architecture:** Server-side only. A private bucket and tables hold books and page chunks (pgvector). An Edge Function `cookbook-process` extracts text per page, chunks it, embeds the chunks and stores them in resumable steps. Edge Function `cookbook-ask` authorizes the caller, embeds the question, retrieves only the caller's household chunks (filter before rank), makes one generation call and returns the answer with sources. The app talks to both online; there is no Drift table and no sync entity, so no schema version is used.

**Tech Stack:** Supabase (Postgres, pgvector, Storage, Edge Functions on Deno), Flutter and Riverpod.

**Spec:** `specs/026-cookbook-library/spec.md`, `plan.md`, `tasks.md`

## Global Constraints

- FR-102: RAG is part of the first slice; filter authorization before retrieval and ranking.
- FR-104: book content is untrusted instructions; limit quoting; keys and embedding services stay behind the server.
- SC-001: another household cannot retrieve a household's chunks. SC-002: after a book is deleted, retrieval stops and chunks are removed; a failed job can resume without duplicates.
- Source book and page are kept on every chunk.
- SQL is additive with RLS, explicit grants and a local two-account pgTAP test. UI copy in Serbian Latin.

## Decisions on open question Q1 (spec 026; approved by Dev 3 on 2026-11-22)

| Point | Call |
| --- | --- |
| Formats | Text PDF and EPUB. Scanned books and OCR are out of this slice. |
| Limits | 15 MB per file, 500 pages, 20 books per household. |
| Embeddings | Gemini embeddings called from the Edge Function with a server secret; 768 dimensions; one pinned model from `EMBEDDING_MODEL`, stored per book; a model change clears and re-embeds its chunks. |
| Quoting | An answer quotes at most 25 words per source and always names book and page. |
| Retry | Processing resumes from `cookbooks.next_page`; chunk inserts are idempotent on `(cookbook_id, page, chunk_index)`. |
| Deletion | Deleting a book removes its chunks (cascade) and its stored file. |
| Provider retention | Approved: book text may go to Gemini for embedding. Questions and retrieved passages may go to the configured text gateway chain (Gemini, Groq, OpenRouter and OpenAI), under each provider's retention terms. |
| Server-side book list and deletion | Approved exception to the local cache/outbox convention: books and files are uploaded once and live on the server; the app reads and deletes them online. Delete storage first so a failure leaves the database path available for retry. |
| Model routing | `AIRouter` is client-side Dart and cannot run in an Edge Function. The server gateway chain is the equivalent for answer generation; embeddings stay on one pinned Gemini model because vectors from different models cannot be mixed. |

## Review Focus

- A question with no relevant passage: answer `unknown`, no invented source.
- A change to `EMBEDDING_MODEL` removes stale vectors and marks the book for re-embedding on its next processing request.
- Every document embedding batch reserves the shared server-side text quota before the provider call.
- A book that contains instructions aimed at the model ("ignore previous rules"): treated as data, never changes the answer format or leaks other households' data.
- A scanned PDF (no text layer): fails with `no_text` instead of an empty ready book.
- Two uploads of the same file, or a retried processing run: no duplicate chunks.
- A member who leaves the household: loses access to its books at once.

## Tasks

### Task 1: Tables, bucket, retrieval function (SQL)
**Files:** Create `supabase/migrations/20261122160000_cookbooks.sql`, `supabase/tests/14_cookbooks_test.sql`
**Produces:** tables `public.cookbooks`, `public.cookbook_chunks`; bucket `cookbooks`; `public.cookbook_search(p_user_id uuid, p_embedding vector(768), p_limit int, p_book_id uuid default null) returns table(chunk_id uuid, cookbook_id uuid, title text, page int, content text, score float8)`, execute for `service_role` only.
- [ ] pgTAP first: two households; member reads own books and not the other's; non-member insert denied; search returns only the caller's household chunks and `p_book_id` of a foreign book returns nothing; deleting a book cascades chunks; a user who left the household gets nothing; bucket policies follow the first path segment.
- [ ] Verify it fails (objects missing), write the migration, verify it passes.

### Task 2: Extraction and chunking (Deno, pure)
**Files:** Create `supabase/functions/cookbook-process/extract.ts`, `chunk.ts`, `extract_test.ts`
**Produces:** `chunkPage(text: string, opts?: {maxChars: number; overlap: number}): string[]`; `extractPdfPages(bytes: Uint8Array): Promise<string[]>`; `extractEpubPages(bytes: Uint8Array): Promise<string[]>`; error code `no_text` when no page has text.
- [ ] Tests: chunk bounds and overlap, whitespace only page gives no chunk, a text-layer PDF fixture yields pages, an image-only PDF gives `no_text`, an EPUB with two chapters yields ordered pages.

### Task 3: Processing function
**Files:** Create `supabase/functions/cookbook-process/process.ts`, `index.ts`, `process_test.ts`
**Produces:** `processBook(deps, bookId): Promise<{status: 'ready'|'failed'|'partial'; nextPage: number}>` with injectable `Deps {download, embed, insertChunks, updateBook, now}`.
- [ ] Tests with fakes: full run sets `ready` and stores page and index per chunk; a mid-run failure leaves `partial` with `next_page`; the rerun continues without duplicates; `no_text` and oversize become `failed` with a code.

### Task 4: Ask function
**Files:** Create `supabase/functions/cookbook-ask/ask.ts`, `index.ts`, `ask_test.ts`
**Produces:** `ask(deps, req: {userId, question, bookId?}): Promise<{status: 'answered'|'unknown'; content: string; sources: {bookId, title, page}[]}>`
- [ ] Tests with fakes: no hits gives `unknown` with no sources; the answer's sources come only from retrieved chunks; a hostile passage does not change the response shape; the question length is bounded; the provider is called once.

### Task 5: Client repository and screens
**Files:** Create `lib/data/cookbook_repository.dart`, `lib/features/cookbooks/…`; Modify the recipes entry
**Produces:** `CookbookRepository` with `list()`, `upload(File)`, `delete(id)`, `ask(question, {bookId})`; a library screen, an ask screen with sources, and "Sačuvaj kao recept" into the existing recipe review.
- [ ] Widget tests with a fake backend: empty state, upload progress and failure, delete confirm, answer with book and page, save as recipe opens review.

## Out of scope here
OCR, scanned books, sharing a book across households, streaming answers.
