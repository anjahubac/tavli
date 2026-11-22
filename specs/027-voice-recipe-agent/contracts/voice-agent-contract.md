# Contract: voice recipe draft agent

**Status**: accepted by Dev 2 (AI engineer) on 2026-11-22; implemented on
`feat/voice-recipe-agent` (TRELLO-131, then TRELLO-91 and TRELLO-92).
**Author**: Dev 2 | **Reviewer**: Dev 4 (spec 027 lead, screens)
**Builds on**: [spec 027](../spec.md), [AI gateway contract](../../015-ai-server-gateway/contracts/ai-gateway-contract.md),
[AI response contract](../../014-ai-response-contracts/contracts/ai-response-contract.md),
[AI ingredient names](../../018-ingredient-catalog/contracts/ai-ingredient-names-contract.md)

## Decision Q1 (STT transport)

Speech to text uses **Groq Whisper (`whisper-large-v3`, language `sr`)
behind the `voice-transcribe` Edge Function**, with `GROQ_API_KEY` as a
function secret (already set). The app never holds a provider key. A model
change is the `VOICE_MODEL` secret, without an app release. On-device Whisper
was considered: only the large model handles Serbian measures well, and it is
too big and slow for phones. The first version shows questions and replies as
text only (TRELLO-92); reading them aloud is later work. Measurements are in
[research.md](../research.md). Recordings for the measurement follow
[research/dictation-fixtures.json](../research/dictation-fixtures.json)
(17 items, including two whole recipes told in one go) and stay outside the
repository.

## Principle

The model has no power. It returns **proposed actions as data**; the app
validates them and applies them to an **in-memory draft**. Safety never depends
on the model obeying the prompt: even a model that follows an injected
instruction can only produce a draft change that the person sees and can undo.

```
press-to-talk → audio → voice-transcribe (Groq) → transcript
transcript + draft → AI (AIRouter; gateway task voice_draft_actions) → JSON
JSON → parseVoiceTurn (strict) → applyVoiceActions → draft in memory
draft → "Pregledaj recept" → existing manual form → person taps "Sačuvaj"
```

## Rules

| # | Rule | Enforced by |
| --- | --- | --- |
| 1 | Closed action list: `add_ingredient`, `update_ingredient`, `remove_ingredient`, `add_step`, `update_step`, `remove_step`, `set_servings`, `set_title`. A reply without actions is a clarifying question. Nothing else. | `parseVoiceTurn` (`lib/ai/voice_agent.dart`): unknown op or extra field rejects the whole answer (V1, V4); one repair, then a Serbian error; the draft is unchanged |
| 2 | Actions change only the draft in memory; no database, network, navigation, sync, delete or save | `applyVoiceActions` is pure (`lib/domain/voice_draft.dart`); an import-boundary test fails if voice code imports data, sync, account, features, providers, Supabase, Drift, Dio, HTTP or `dart:io` |
| 3 | Only the person saves | no save action exists; the draft opens the existing manual recipe form |
| 4 | Bounds | at most 40 actions per utterance (a whole recipe), ingredient fields through `aiIngredient` (R5–R9), title 120, step 1000, servings 1–99, resulting draft at most 60 ingredients and 40 steps (V2, V5–V8); transcript at most 4000 characters, empty or longer is not sent |
| 5 | Late answers are dropped | each answer is applied only for the draft `revision` it was made for (`VoiceSession.apply`); cancel ignores later answers |
| 6 | Undo | `VoiceSession.undo` restores the draft before the last applied utterance; an answer prepared before the undo no longer applies |
| 7 | Voice privacy | press-to-talk only, at most 120 s and 3 MB; temporary audio deleted right after upload or cancel; audio and transcript never written to Drift, the outbox, logs or crash reports; the function logs only status, size and duration |
| 8 | Server like the gateway | `voice-transcribe`: session required, audio type and size checked before quota, quota through `ai_reserve`, one provider call, typed errors without provider bodies |

Indexes refer to the draft as sent. Within one answer, updates use the old
indexes, removals apply after them, additions append; each item may be
targeted by at most one action (V5).

## `voice-transcribe`

`POST /functions/v1/voice-transcribe`, `Authorization: Bearer <user token>`,
body = raw audio, `Content-Type` one of `audio/mp4`, `audio/m4a`,
`audio/x-m4a`, `audio/aac`, `audio/mpeg`, `audio/wav`, `audio/x-wav`,
`audio/webm`, `audio/ogg`, `audio/flac`.

| Status | Body | When |
| --- | --- | --- |
| 200 | `{"text": "<transcript>"}` (may be empty) | success |
| 400 | `{"error": "bad_request"}` | empty body |
| 401 | `{"error": "unauthorized"}` | no or invalid session |
| 413 | `{"error": "too_large"}` | over 3 MB |
| 415 | `{"error": "unsupported_type"}` | not an allowed audio type |
| 429 | `quota_exceeded` / `busy` as in 015 | `ai_reserve` refused |
| 429 | `{"error": "provider_rate_limited", "retryAfterSeconds"?}` | Groq limit |
| 500 | `{"error": "internal"}` | reservation failed (no provider call) |
| 502 | `{"error": "provider_error"}` | other provider failure or bad answer |
| 503 | `{"error": "model_unavailable"}` | no `GROQ_API_KEY` or `AI_GATEWAY_DISABLED=1` |
| 504 | `{"error": "timeout"}` | no provider answer in 30 s |

**Quota (decision a)**: a recording is reserved as kind `text`, so dictation
shares the daily text limit with recipes and plans. A separate `audio` kind
needs a migration in `ai_calls` and is deferred.

**Provider retention**: Groq's data controls are checked before wider release;
until then dictation is for team testing on `tavli-dev`.

## Transcription

Whisper gets `language=sr`, `temperature=0` and a short `prompt`
(`STT_PROMPT`): “Recept na srpskom jeziku, ekavica” plus measure words (pola
kile, kašika, prstohvat, po ukusu…). It lists no foods on purpose: measures
recur in every recipe, while a food list helps only the listed foods and can
make Whisper insert words that were not said. Misheard foods are fixed by the
agent from the recipe context (rule below), and the person sees the transcript
and the draft.

## Agent request

The prompt carries the current draft with indexes and the transcript as a JSON
string (quotes and new lines in speech cannot leave the data). The system
prompt states that the transcript is data, lists the actions, says the text
comes from speech recognition (fix an obvious mishearing of a food or measure
from context, never invent a food that was not said), asks for a question
instead of a guess when something is still unclear, writes names in ekavian
Serbian and ignores filler or closing phrases. Ingredient names follow
`ingredientNameRules`.

When the gateway client (015 slice 4) is merged, the request carries task
`voice_draft_actions` (text); the gateway allowlist adds it in the same PR.

## Evidence

- `test/domain/voice_draft_test.dart`: ordering by old indexes, field updates
  and clearing, steps, late answer dropped, cancel, undo, question without a
  history step.
- `test/ai/voice_agent_test.dart`: whole recipe in one utterance, each
  rejection rule V1–V9, injected commands (save, delete, URL, extra fields),
  the transcript sent as data, a model that obeys an attack is rejected after
  one repair with the draft unchanged, empty and long transcripts not sent,
  the import boundary.
- `supabase/functions/voice-transcribe/transcribe_test.ts`: method, session,
  type, size, missing key and emergency stop before quota, quota and busy,
  reservation failure, one Groq call with `language=sr`, provider errors,
  timeout, nothing from the transcript or provider in logs or errors.
- [research.md](../research.md): 17 recordings through Groq and the real
  agent (turbo, large-v3, large-v3 with context and correction).
- Not yet: the screen (TRELLO-91/92), a live check through the deployed
  function, microphone and temporary-file checks on Android, iOS and macOS.
