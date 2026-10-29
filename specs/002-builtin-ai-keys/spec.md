# Feature Specification: Built-in Tavli AI keys

**Feature Branch**: `002-builtin-ai-keys`

**Created**: 2026-10-30

**Status**: Draft

**Input**: User description: "Keys should be local to start with (built into the app from a local, never-committed file); later I plan to move them to Cloudflare once the app is tested and finished. The user's own keys take priority; when the user has no key the app uses the built-in Tavli AI."

> All UI text is Serbian (Latin script). Quoted strings are the exact UI copy.

## Clarifications

### Session 2026-10-30

- Q: When the user's own key for a provider is rate-limited, may the app fall back to the built-in key for the same model? → A: Yes. For every model the user's key is tried first, then the built-in key, before moving to the next model.
- Q: Are pauses (rate-limit cooldowns) shared between the user's key and the built-in key? → A: No. Each key has its own pause per model; a limit on one never pauses the other.
- Q: If a built-in key is rejected by the provider, should the user be told to enter a new key? → A: No. A rejected built-in key is skipped silently for the rest of the session; only a rejected *own* key is surfaced on the AI keys screen.
- Q: Can the user switch the built-in AI off? → A: Not in this feature (no product need yet); out of scope.
- Q: Should the built-in key be visible or checkable on the AI keys screen? → A: No. It is never displayed; the screen only says it is in use.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - AI works out of the box (Priority: P1)

A person installs a Tavli build that was made with built-in keys and, without
entering any key, creates a recipe with AI (e.g. the chain test "Probaj AI").
It works.

**Why this priority**: removes the biggest barrier — nobody has to visit three
provider consoles before the app does anything useful.

**Independent Test**: build with built-in keys, delete all own keys, run "Napravi probni recept"; a recipe appears.

**Acceptance Scenarios**:

1. **Given** a build with built-in keys and no own keys, **When** the user runs an AI task, **Then** it succeeds using the built-in key.
2. **Given** a build without built-in keys and no own keys, **When** the user runs an AI task, **Then** behaviour is as before ("Nijedan model nije dostupan. Proveri ključeve.").

---

### User Story 2 - Own key takes priority, built-in is the backup (Priority: P1)

A person who saved their own key keeps using it. When their key hits a free-tier
limit (or is rejected), the same model is tried with the built-in key before
the app moves on to the next model.

**Why this priority**: respects the user's own quota first while keeping AI available.

**Independent Test**: with both keys present, make the own key rate-limited; the answer still comes from the same model, via the built-in key.

**Acceptance Scenarios**:

1. **Given** both keys for a provider, **When** an AI task runs, **Then** the own key is used first and the built-in key is not used.
2. **Given** both keys and the own key is rate-limited on a model, **When** an AI task runs, **Then** the same model is retried with the built-in key.
3. **Given** the own key is paused on a model, **When** the next task runs, **Then** the own key is skipped for that model until the pause ends, while the built-in key can still be used.
4. **Given** the built-in key is paused on a model, **Then** the own key for that model is unaffected.
5. **Given** the own key is rejected, **Then** the provider still works via the built-in key, and the AI keys screen can still show that the own key needs replacing.

---

### User Story 3 - The user sees which AI is in use (Priority: P2)

On "Profil → AI ključevi", a provider without an own key but with a built-in key
shows "Koristi se ugrađeni Tavli AI". In the chain test log, attempts made with
the built-in key are marked "Tavli AI".

**Why this priority**: transparency; explains why AI works without keys.

**Independent Test**: open the AI keys screen in a build with built-in keys and no own keys; the text is shown per provider.

**Acceptance Scenarios**:

1. **Given** a built-in key for Gemini and no own Gemini key, **When** the screen opens, **Then** the Gemini card shows "Koristi se ugrađeni Tavli AI".
2. **Given** an own Gemini key, **Then** that text is not shown for Gemini.
3. **Given** no built-in keys at all, **Then** the screen looks as before.
4. **Given** the chain test ran with the built-in key, **Then** the attempt log marks those attempts with "Tavli AI".

---

### Edge Cases

- Built-in value present but empty → treated as no built-in key.
- Own key equals the built-in key → still two tries at most per model; acceptable.
- All keys of all providers paused → "Svi besplatni limiti su potrošeni. Pokušaj ponovo posle HH:MM." with the earliest time across both keys.
- Upgrading from a version where pauses were tracked per model only → old pauses are discarded (they expire within a day anyway).
- Saving a new own key clears the "rejected" state for the own key only.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST support optional built-in keys for each provider, supplied at build time from a local file that is never committed.
- **FR-002**: For each model in a chain, the app MUST try the user's own key first, then the built-in key.
- **FR-003**: Rate-limit pauses, "model not available" and "key rejected" states MUST be tracked separately per key origin (own vs built-in).
- **FR-004**: Pauses MUST persist across app restarts per model and key origin.
- **FR-005**: A rejected built-in key MUST NOT prompt the user to change keys.
- **FR-006**: The AI keys screen MUST show "Koristi se ugrađeni Tavli AI" for each provider that has a built-in key and no own key, and MUST never display the built-in key.
- **FR-007**: The chain test log MUST mark attempts made with the built-in key with "Tavli AI".
- **FR-008**: The key source MUST be replaceable (e.g. by a future Cloudflare proxy) without changing the fallback logic.
- **FR-009**: The repository MUST contain an example key file with empty placeholder values only.

### Key Entities

- **Key origin**: where a key comes from — own (entered by the user) or built-in (Tavli).
- **Credential**: a provider, a key value and its origin.
- **Model status**: pause time, daily usage and last error per provider, model and key origin.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a build with built-in keys, a new user gets an AI recipe with zero setup steps.
- **SC-002**: When the own key is rate-limited, 100% of tasks with an available built-in key for the same model still succeed on that model.
- **SC-003**: No key value appears in the repository, in logs, or on any screen.
- **SC-004**: All fallback scenarios above are covered by automated tests that run without network.

## Assumptions

- Built-in keys are temporary: they ship inside the app binary and can be extracted by a determined person; acceptable for personal/test builds until the Cloudflare proxy (roadmap) replaces them.
- Provider free-tier limits are per key, so separate pauses per key origin are correct.
- One built-in key per provider is enough.
- Existing own-key storage (Keychain/Keystore) is unchanged.
