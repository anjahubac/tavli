# Implementation plan: Voice-assisted recipe drafts

**Status**: scoped proposal; runtime implementation not started by this revision.
**Spec**: [requirements](spec.md) | **Product lead / implementer / proposed reviewer**: Dev 4 / Dev 2 (Ceviz) / Dev 3
**Baseline**: dev 207c94c; every implementing branch starts from then-current origin/dev.

## Existing boundaries and proposed files

- `lib/features/recipes/` for recording, transcript review, draft preview and text questions
- `lib/ai/` for the voice transport and text facade through `AIRouter`
- `lib/domain/` for allowlisted draft edits
- `supabase/functions/voice-transcribe/` for the proposed audio endpoint
- `supabase/functions/ai-gateway/` for the recipe draft text task from 015
- `android/`
- `ios/`
- `macos/`

Items marked new/proposed/external do not exist at baseline. Verify exact existing
files and consumers before editing; new files remain in current feature/domain/
data/AI/account/sync layers. Shared providers and schema versions are coordinated.

## Contract and data plan

1. Flutter records a bounded clip and sends it with the signed-in session to
   `POST /functions/v1/voice-transcribe`. The Edge Function checks the session,
   format, limits and quota, then makes a bounded Groq transcription call using
   the server-side `GROQ_API_KEY`. It returns a transcript to Flutter.
2. After Flutter receives the transcript, `AIRouter` submits it together with
   the current draft in a separate text POST to `ai-gateway`. The text model
   follows the environment's text chain. The audio call and its provider are
   independent of the draft model order. `AIRouter` owns text fallback.
3. Flutter validates the proposed edits and applies them to the active draft.
   It renders optional clarification questions as text. A spoken reply repeats
   both requests. A typed reply goes directly to the text request. If text
   processing fails, the current transcript can be retried in memory. The
   existing editor owns confirmation and saving.

Audio and transcripts are transient user content. Record provider retention,
processing location and rollout controls in research before enabling the
feature. No audio or raw transcripts enter storage, logs or the sync outbox.
The confirmed recipe uses the existing account-scoped persistence path.

Producer dependencies: [014](../014-ai-response-contracts/spec.md), [015](../015-ai-server-gateway/spec.md), [018](../018-ingredient-catalog/spec.md)

Use [shared boundaries](../011-team-development/contracts/shared-boundaries.md)
and the [contract template](../../.specify/templates/contract-template.md).
Before implementation, record typed fields, validation, identity/units/CivilDate,
error/retry/undo, ownership, compatibility and producer/consumer fixtures. If data
changes, add data-model.md with current→target columns and a reviewed migration;
allocate drift version only after preceding schema merges. New SQL is additive
where possible, with RLS/grants and local two-account tests. Applied SQL is immutable.
If no schema change is needed, explicitly record that decision in the slice PR.

## Delivery slices

1. Prototype Groq transcription on synthetic Serbian dictation. Measure latency
   and accuracy for ingredients, quantities, units and spoken corrections.
   Verify recording, permissions and cleanup on Android, iOS and macOS, then
   use the findings to resolve Q1 and record remaining effort.
2. Merge the agreed contract/fixtures first; no consumer branch stacks on an
   unmerged producer. Independent research/tests may proceed in developers' existing
   checkouts, with one active writer per checkout; no automatic extra worktrees.
3. Implement recording and Groq transcription, then the separate text POST and
   draft reducer. Cover failure, typed input, clarification and retry without
   retranscription; keep phase boundaries in tasks.md.
4. Integrate consumers after producer merge, preserving offline/replay and previous
   UI/quantity behavior. Run relevant 012/013 gates and update real evidence.

## Constitution check (3.0.0)

| Gate | Required response before implementation |
| --- | --- |
| I | English docs; exact Serbian Latin UI/copy for changed screens |
| II | Preserve outbox/account scope; explicit personal/device/reference classification |
| III | Any AI through AIRouter and validated task contract; N/A documented if none |
| IV | No real secrets/logged private content; apply 012 trust-boundary controls |
| V | Test-first logic/parsing; local SQL/Edge tests when backend changes |
| VI | Phone/wide/text/motion/keyboard proof for UI; N/A for technical-only slice |
| VII | Reviewable task slices; generated files via generator only |
| VIII | This canonical spec, owned dev-based branch/task IDs, no stacking |
| IX | Existing paths/interfaces; justify dependencies and migration decisions |
| X | Named human reviewer, producer/consumer contract and schema coordinator |

These are design obligations, not executed pass results. Any violation blocks Ready
until resolved under governance. No dependency is added by this documentation;
implementer records each proposed package/service with a reason before adoption.

**Dependency (2026-11-22, Dev 2)**: `record` ^7.2.0 — microphone capture to a
temporary AAC/WAV file on Android, iOS, macOS and Windows behind
`VoiceRecorder`; Flutter has no built-in recorder, and the plugin is the
maintained cross-platform option. Coordinator for `pubspec.yaml`: Dev 4.
Platform changes: `RECORD_AUDIO` (Android), `NSMicrophoneUsageDescription`
(iOS, macOS) and the macOS `device.audio-input` entitlement.

## Verification, rollout and risks

Use [testing 013](../013-testing-strategy/spec.md), its journey matrix, and
[security 012](../012-security-baseline/spec.md). Tests must prove the scenarios
in spec.md and source task outcomes using synthetic data/fake AI. Default Flutter
tests do not contact a network; explicit guarded integration uses local services.
No speculative hosted deployment or publication. Record old-client/snapshot
compatibility, pending-outbox migration, failure/undo and forward recovery for
state changes. No destructive reset as a migration. Platform/source/legal/retention
limits from open questions remain release gates. UI follows the design canvas and the
UI standard; do not invent layouts or move components into the package incidentally.
