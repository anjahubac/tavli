# Spike: photo-to-recipe timing against Edge Function limits

**Spec**: [015](spec.md) FR-001 / D2-003, Q2 | **Trello**: #35 | **Date**: 2026-11-17
**Author**: Dev 2 | **Decision owner**: team (card #35 “Potreban čovek”)

## Question

Does one “photo → recipe” request fit the Supabase Edge Function limits, so the
built-in-key gateway (#36) can be a plain synchronous function? If not, which
other path should image requests take?

## Limits (Supabase docs, read 2026-11-17)

From [Edge Function limits](https://supabase.com/docs/guides/functions/limits):

| Limit | Value | When exceeded |
| --- | --- | --- |
| Request idle timeout | 150 s without a response | client gets `504` |
| Wall clock per worker | 150 s (Free), 400 s (paid) | worker shut down, `546` |
| CPU time per request | 2 s; async I/O (waiting on the provider) does not count | `546` |
| Memory | 256 MB | `546` |

For a synchronous gateway, the binding limit is the **150 s idle timeout**,
regardless of plan.

## Method

- The real app path on a local Windows build (`RecipeAI.fromImage`: client
  downscale to ≤ 1600 px JPEG, then `AIRouter` with the default vision chain and
  built-in keys from `--dart-define-from-file`). A wrapper client timed every
  provider call. The script is local-only and not committed; no Supabase project
  was called and no recipe content was recorded.
- 24 inputs: 15 distinct real recipe photos (screenshots, phone and chat photos),
  8 generated variants (4032 px phone JPEG, lossless PNG, rotated 90°, 700 px
  grayscale q35) and 1 non-recipe image.
- Then 5 photos sent directly to each vision model to time models individually.
- Gateway CPU: the gateway's own work (parse request, size check, build the
  provider request, parse the reply) benchmarked in Node.js (V8, the engine
  Deno uses) for 0.3–1.5 MB JPEG payloads.
- Only the Gemini built-in key was configured (Groq and OpenRouter absent), so
  the chain ran Gemini Flash → Gemini Pro → Gemini Flash-Lite. Free tier.

## Results

**Payload.** After client downscaling, every input became a 37–383 KB JPEG
(≤ 512 KB base64), including the 1.76 MB / 4032 px phone variant (→ 349 KB).
Downscaling stays on the device (26–657 ms) and never reaches the gateway.

**Gateway CPU.** 0.3–3.1 ms per request on average for 0.3–1.5 MB JPEGs, against
the 2 s limit. Not a constraint.

**Provider calls** (all calls from both phases):

| Model | Outcome | Calls | Median | p90 | Max |
| --- | --- | --- | --- | --- | --- |
| Gemini Flash-Lite | success | 26 | 5.3 s | 9.6 s | 15.4 s |
| Gemini Flash-Lite | transient error | 3 | 9.2 s | — | 30.1 s (timeout) |
| Gemini Flash | transient error (mostly 30 s timeout) | 17 | 30.1 s | 34.8 s | 49.2 s |
| Gemini Flash | rate limit (429) | 6 | 0.6 s | — | 0.6 s |
| Gemini Pro | rate limit (429) | 6 | 0.6 s | — | 0.7 s |

**Whole request through the router** (what one user action costs):

- 21 of 23 recipe photos succeeded (all through Flash-Lite); 2 failed after both
  usable models failed (60.5 s and 39.5 s). The non-recipe image correctly
  returned `not_a_recipe` in 1.4 s.
- Median 35.5 s, maximum 60.5 s. Most of it was Gemini Flash timing out at 30 s
  before the router fell back. When Flash was skipped (rate-limited), requests
  took 2.6–15.5 s.

## Conclusions

1. **A single model attempt fits easily.** The slowest success was 15.4 s, and a
   failing attempt is cut by the model timeout (30 s; 60 s for Gemini Pro).
   Payload and CPU are far below their limits.
2. **The full fallback chain inside one request does not fit safely.** With all
   five vision models configured, the timeouts alone add up to
   30 + 30 + 60 + 30 + 30 = **180 s**, and a non-timeout transient error retries
   the same model once more. That exceeds the 150 s idle timeout, and the client
   would get a `504` with no recipe. In this run two timeouts already took 60.5 s
   with only Gemini configured.
3. **No queue is needed.** The images are small and one attempt is short.

## Recommendation (for the team to choose, Q2)

**A (recommended): synchronous gateway, one model attempt per call.** The
gateway runs exactly one provider call with a hard server deadline (proposed
60 s, below 150 s) and returns a typed error (`timeout`, `rate_limited`,
`retry_after`). The existing client `AIRouter` stays the single retry/fallback
owner (FR-103) and calls the gateway once per model. No new infrastructure;
built-in keys still never leave the server.

B: synchronous gateway that runs the chain server-side with a total budget of
about 120 s, stopping before the idle timeout. Simpler client, but two retry
owners have to be reconciled, and a slow chain still ends in an error.

C: queued job (insert job, background worker, client polls or uses Realtime).
Unnecessary at these sizes; adds a table, RLS, cleanup and polling UI.

## Extraction quality (secondary, same 15 photos)

All 15 photos were re-run through Gemini Flash-Lite. The extracted recipes were
compared by hand with the images, which stayed on the developer's machine and
are not committed.

- **Correct:** all 15 titles. Cyrillic was transliterated to Latin, English and
  Croatian were translated to Serbian, and handwriting, rotated photos and pages
  with a second recipe were handled (only the main recipe was taken). Most
  quantities were exact, including ranges (“2–3 veze” → 2.5 plus a note) and
  “1 dl” → 100 ml.
- **Errors that reach shopping:** one handwritten quantity was misread (600 g
  read as 500 g); “čaša” was replaced by “šolja” three times and “kafena šolja”
  by “šolja” once (200 vs 250 ml in the unit vocabulary); one ingredient named
  only in the steps was missing from the list.
- **Presented as fact:** servings were invented for 8 of 15 recipes that state
  none. A cut-off recipe was returned without a warning.
- **Noise:** wrong categories (oil, pasta, water), greetings (“Prijatno!”) as
  steps, partly invented steps when the photo had almost none.

Model reading errors (the 600/500 misread) depend on the model. The rest can be
steered by the prompt in #34 (keep unit words verbatim, mark estimated servings,
list every ingredient used in the steps, no greetings or invented steps). Food
categories come from the catalog once #20 exists. The user review before saving
(“Proveri predlog”) stays the final safeguard.

## Side findings (not fixed in this spike)

- **Gemini Flash is the first vision model but failed after 30 s or more on 16
  of 17 attempts** that were not rate-limited, so most photo imports waited 30 s
  before Flash-Lite answered in about 5 s. Whether `gemini-flash-latest` now
  points to a slower reasoning model or the service was overloaded is unknown
  from one session. A follow-up is proposed: re-measure, then either raise the
  Flash timeout or put Flash-Lite first for vision (owner Dev 2, `lib/ai/`).
- The free-tier daily quota for Flash and Pro ran out during the run (429).
  Shared built-in keys exhaust quickly. This supports the per-user quota in
  FR-102.

## Limits of this evidence

One evening, one network, free tier, Gemini only. Groq and OpenRouter were not
measured because those built-in keys were absent. The team plans a paid OpenAI
key for built-in AI. It was not measured, and the app has no OpenAI provider yet
(`AIProvider` lists Gemini, Groq and OpenRouter). Conclusion 1 does not depend
on the model: any single call is bounded by its timeout, and the gateway
deadline applies. Edge Function timing was not
measured on a deployed function: Docker is unavailable locally and hosted
deploys are CI-only. The function adds only its own CPU time (measured) and one
extra network hop.
