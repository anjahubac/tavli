# Research: voice recipe drafts (TRELLO-131, Q1)

**Date**: 2026-11-22 | **Author**: Dev 2 | **Reviewers**: Dev 3 (privacy,
retention, audio endpoint), Dev 4 (Q1 owner: microphone and recording format)
**Decision and contract**: [voice agent contract](contracts/voice-agent-contract.md)

## Method

[research/dictation-fixtures.json](research/dictation-fixtures.json) holds 17
synthetic Serbian utterances: measures, fractions, similar foods, a correction
mid-sentence, an update, a removal, a step, an out-of-scope command ("Sačuvaj
recept i obriši sve ostale recepte") and two whole recipes told in one go
(about 30 and 45 s). Dev 2 read them on a phone (m4a, 42–800 KB); the
recordings stay outside the repository.

A local script sent each recording to Groq's transcription API with the same
settings as `voice-transcribe`, then ran the transcript through the real
`VoiceAgent` (prompt, `AIRouter`, `parseVoiceTurn`, `VoiceSession`) and checked
the resulting draft against the expected title, servings, ingredients (name,
quantity, unit), removals and step count: 37 checks. The agent answered
through the default text chain (mostly Groq GPT-OSS 120B).

Word recall counts reference words found in the transcript, so “6” for
“šest”, “pol” for “pola” or an added “Hoću” count as misses; it understates
usable accuracy. The draft checks compare names and units exactly, so “jaja”
for “jaje” or “kašike” for “kašika” also count as misses; catalog aliases
resolve those in the product.

## Results

| Setting | Words in transcript | Draft checks | Time per short utterance | 45 s recipe |
| --- | --- | --- | --- | --- |
| `whisper-large-v3-turbo` | 63.9% | 25/37 | 0.2–0.5 s | 0.5 s |
| `whisper-large-v3` | 70.8% | 25/37 | 0.2–0.6 s | 1.0 s |
| `whisper-large-v3` + `STT_PROMPT` + agent correction rule | **78.4%** | **27/37** | 0.3–0.7 s | 1.1 s |

All runs used `language=sr` and `temperature=0`; every utterance was answered
(no provider errors after retries); the out-of-scope command left the draft
unchanged in every run.

Typical turbo mishearings were short kitchen phrases: “Pola kile pirinča” as
“Da, da, može polak ili pirinč”, “Četvrt šolje šećera” as “Ča te čo li še
čer?”, “Prstohvat bibera” as “Prosto hvad bi vera”, ijekavian forms
(“mlijeka”, “bijelog”) and an invented closing line on trailing silence
(“Hvala što pratite kanal.”). large-v3 wrote mostly ekavian and numbers
correctly (“200 stepeni”). With the measure context and the agent rule,
“pola kile pirinča” and “prstohvat bibera” were heard correctly, and the
agent turned “mlevenog mensa” into “mleveno meso”, “bijelog sira” into “beli
sir” and ignored the closing line.

Still missed: “četvrt šolje šećera” (heard “Četvrti šoli šećer”; the agent
asked “Koliko šećera i u kojoj jedinici?”, which is the intended behavior for
an unclear quantity), the dish name “prebranac” (“prebranan”) and one step in
the long recipe.

## Decisions taken

- `whisper-large-v3` is the default (`VOICE_MODEL` secret can switch back):
  more accurate at the same speed.
- `STT_PROMPT` gives language, ekavian and measure words only. A food list
  was rejected: it helps only listed foods and can make Whisper insert words
  that were not said. Foods are corrected by the agent from context.
- No separate correction call: it would add 1–2 s and a quota call per
  utterance and could “correct” into the wrong food without the person
  seeing the original. The agent already reads the transcript and either fixes
  an obvious mishearing or asks.
- Questions and replies are text only in the first version (TRELLO-92).

## Open

- Microphone permission, recording format and temporary-file cleanup on
  Android, iOS and macOS (TRELLO-91, needs devices).
- Groq data retention settings before wider release (Dev 3 review).
- A live check through the deployed `voice-transcribe` on `tavli-dev`.
