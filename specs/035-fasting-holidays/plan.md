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

1. The app sends the question and today's civil date to `ai-gateway`
   (`fasting_question`), with the user's JWT.
2. The function embeds the question with the shared model, takes the 5 to 8
   closest chunks, preferring the current and next year.
3. One model call from the server allowlist (Gemini, Groq or OpenRouter):
   answer briefly in Serbian Latin, only from the chunks, otherwise say you do
   not know.
4. The function checks every date in the answer against the chunks, then
   returns the answer and its sources, or a typed error from 015.
5. With a user's own key, retrieval still runs on the server; only the model
   call goes direct, as for other AI features.

## Contract and data plan

- Calendar: `fastingLevelFor(CivilDate) -> FastingDay {level, fastName?, feastName?}`
  and `nextFast(CivilDate)`; levels `water`, `oil`, `fish`, `none`.
- Knowledge chunk: id, kind (`calendar` | `explanation`), year (nullable),
  text, source label, embedding, model id, created_at. Global reference data;
  RLS read for authenticated users; write only by the maintenance script.
- Recipe fasting label: additive nullable column plus source (`ai` | `user`),
  following the 019 recipe-label migration pattern (user values win).
- Household setting: scope and strictness, owned by Dev 3 with the other
  household preferences.

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
