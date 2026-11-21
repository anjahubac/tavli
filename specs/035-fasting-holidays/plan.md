# Implementation plan: Orthodox fasts and holidays

**Status**: scoped proposal; runtime implementation not started.
**Spec**: [requirements](spec.md) | **Lead/review**: Dev 2 / Dev 4
**Baseline**: dev 36c9c7c; every implementing branch starts from then-current origin/dev.

## Existing boundaries and proposed files

- `lib/domain/ (new: orthodox calendar, pure Dart, no Flutter imports)`
- `lib/ai/ (new task type for fasting questions through AIRouter)`
- `supabase/functions/ai-gateway/ (planned in 015; new request type)`
- `supabase/migrations/ (knowledge chunks with embeddings, shared with 026)`
- `scripts/ (new: generate per-year calendar chunks from the Dart rules)`
- `lib/features/home/ (status card), lib/features/fasting/ (question screen and panel)`
- `lib/features/planning/ (fasting filter in plan rules)`
- `lib/features/recipes/ (fasting label on recipe, correction)`

Items above do not exist at baseline. Verify exact existing files and consumers
before editing. Shared providers, routes and schema versions are coordinated.

## Flow of one question

1. `AIRouter` sends `fasting_question`, the question, today's civil date and
   the candidate allowlisted model to the gateway with the user's JWT.
   Every account uses this route for fasting questions.
2. Authenticate, validate and reserve quota before provider work. Embed the
   question and retrieve up to eight relevant chunks from the fasting corpus.
   Index the current and next two civil years. Honor an explicit supported
   year first. For yearless queries, resolve relative dates from the supplied
   civil date and prefer the current and next year where applicable.
3. The gateway builds the prompt and makes one generation attempt per
   request. The model returns structured references to the relevant calendar
   facts or approved explanatory passages, or an unknown result.
4. Check the references against the retrieved material, including the
   requested event, occurrence and date field for calendar answers. Render
   the Serbian Latin answer and sources on the server using the validated
   facts and passages. For weak retrieval or failed validation, return
   “ne znam”. Return transport and quota errors using 015.

## Contract and data plan

- Calendar: `fastingRuleFor(CivilDate) -> FastingDay` with the allowed food
  categories, any time restriction, and optional fast and feast names.
  `nextNamedFast(CivilDate)` returns the next named fasting period for Home.
- Knowledge chunk: id, kind (`calendar` | `explanation`), year (nullable),
  text, source label, embedding, model id, created_at. Global reference data;
  RLS read for authenticated users; write only by the maintenance script.
  Keep one canonical occurrence for each named fast, with complete start
  and end dates. Index its reference in each covered civil year it overlaps,
  so 31 December and 1 January resolve to the same Nativity fast occurrence.
  Scope access to fasting reference chunks before ranking, independently of
  cookbook authorization.
- Recipe fasting label: additive nullable column plus source (`ai` | `user`),
  following the 019 recipe-label migration pattern (user values win).
- Household setting: scope and strictness, owned by Dev 3 with the other
  household preferences. Persist the effective fasting options on the
  approved plan using the plan snapshot rules so replacements use the
  options the user confirmed.

Use [shared boundaries](../011-team-development/contracts/shared-boundaries.md)
and the [contract template](../../.specify/templates/contract-template.md).
Applied SQL is immutable; drift versions are allocated only after preceding
schema merges.

## Delivery slices

1. Calendar module with SPC-checked fixtures (no network, no UI).
2. Knowledge base table and generator script; explanatory texts written by
   the team in their own words.
3. Gateway request type and retrieval; fake-AI tests for “ne znam” and the
   date check.
4. Home card and question screen/panel per the canvas.
5. Recipe fasting label, then the household setting, then plan filtering.
6. Catalog-computed label after 018 merges.

## Constitution check (3.0.0)

| Gate | Required response before implementation |
| --- | --- |
| I | English docs; exact Serbian Latin UI copy from spec.md |
| II | Calendar and chunks are reference data; setting is household data; answers stay on device |
| III | AI only through AIRouter and the 015 gateway with a validated response |
| IV | No secrets or question text in logs; 012 trust-boundary controls |
| V | Test-first calendar rules and answer validation; local SQL/Edge tests |
| VI | Phone/wide/2× text/keyboard proof for card, screen and panel |
| VII | Reviewable slices in the order above |
| VIII | This spec, dev-based branches, no stacking |
| IX | Existing paths/interfaces; vector table shared with 026 |
| X | Named reviewer and schema coordinator for each slice |

## Verification, rollout and risks

Tests prove spec scenarios with synthetic data and a fake AI; default Flutter
tests make no network calls. Risks: calendar rules wrong for fish/oil days
(mitigated by Q1 review and fixtures), free-tier quota limits (Q5), and the
shared vector table ordering with 026 (Q2). The generator runs once a year and
before each release that changes rules. UI follows the design canvas and the UI
standard; do not invent layouts.
