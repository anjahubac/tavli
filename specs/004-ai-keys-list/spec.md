# Feature Specification: AI keys list

**Feature Branch**: `004-ai-keys-list`

**Created**: 2026-10-30

**Status**: Implemented

**Input**: User description (Serbian, translated): "I want the API keys page changed: one field for adding an API key (any key, so don't put 'Gemini API ključ' or similar in the field label) and the ability to add more than one; below it an overview of the API keys the user has already added (if any)."

> All UI text is Serbian (Latin script). Quoted strings are the exact UI copy.

## Clarifications

### Session 2026-10-30

The owner was away; these answers are the recommended defaults, taken so work could continue.

- Q: How does the app know which service a key belongs to? → A: From the key's prefix (`AIza…` Gemini, `gsk_…` Groq, `sk-or-…` OpenRouter). If the prefix is unknown, the user picks the service from a list before saving.
- Q: Is a key checked before it is saved? → A: Yes, with the free model-list request. A rejected key is not saved. If the check cannot run (no network), the key is saved and marked "Nije provereno".
- Q: Several keys for the same service — in what order are they used? → A: In the order they were added; each key has its own rate-limit pauses, so when one key's free limit runs out the next key of the same service is tried before the built-in Tavli key.
- Q: How is a saved key shown? → A: Service name, the last 4 characters ("••••a1B2"), date added and status. The full key is never shown again.
- Q: What happens to the single key per service saved by earlier versions? → A: It is moved into the new list automatically on first open.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Add any key from one field (Priority: P1)

On "Profil → AI ključevi" there is one field "API ključ" and a button "Dodaj
ključ". The person pastes a key from any supported service; the app recognises
the service, checks the key and adds it to the list below.

**Why this priority**: the page currently has three provider-specific forms; one field is simpler and was explicitly requested.

**Independent Test**: paste a Groq-format key, tap "Dodaj ključ", see it in the list as "Groq".

**Acceptance Scenarios**:

1. **Given** a key starting with `gsk_`, **When** "Dodaj ključ" is tapped, **Then** it is checked, added under "Groq", the field is cleared and "Ključ je dodat (Groq)." is shown.
2. **Given** a key with an unknown prefix, **Then** "Izaberi servis" appears with Gemini, Groq, OpenRouter, and "Dodaj ključ" stays disabled until one is picked.
3. **Given** the service rejects the key, **Then** "Ključ nije ispravan ili je opozvan." is shown and nothing is saved.
4. **Given** the check fails for network reasons, **Then** the key is saved with status "Nije provereno".
5. **Given** the same key is already saved, **Then** "Ovaj ključ je već dodat." is shown.
6. **Given** an empty field, **Then** "Dodaj ključ" is disabled. The field label never names a service.

---

### User Story 2 - See and manage added keys (Priority: P1)

Below the field, "Dodati ključevi" lists every saved key: service, "••••" plus
the last 4 characters, "Dodat {datum}" and status ("Radi", "Odbijen",
"Nije provereno"). Each key has "Proveri" and "Obriši". With no keys the
section says "Još nema dodatih ključeva."

**Why this priority**: the user must see what is saved and remove keys.

**Acceptance Scenarios**:

1. **Given** two Gemini keys and one Groq key, **Then** all three are listed, grouped by service in add order.
2. **Given** "Obriši", **Then** "Obrisati ključ ••••a1B2?" is asked; on "Obriši" the key is removed.
3. **Given** "Proveri", **Then** the status updates and the chain models available for that key are shown.
4. **Given** no own key for a service and a built-in key, **Then** a note "Koristi se ugrađeni Tavli AI: {servisi}" is shown under the list.

---

### User Story 3 - More keys mean more free quota (Priority: P2)

When one key of a service hits its free limit, the same model is tried with the
person's next key of that service, then with the built-in key, before moving to
the next model.

**Acceptance Scenarios**:

1. **Given** two own Gemini keys and the first is rate-limited, **When** an AI task runs, **Then** the same model answers using the second key.
2. **Given** one key is rejected, **Then** only that key is skipped and marked "Odbijen"; other keys keep working.

### Edge Cases

- Key pasted with spaces or a trailing newline → trimmed.
- Old single key per service from an earlier version → appears in the list once, no duplicate after restart.
- Deleting a key while a request using it is running → request finishes; the key is not used again.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The AI keys page MUST have one input labelled "API ključ" (no service name) and a "Dodaj ključ" button.
- **FR-002**: The app MUST detect the service from the key prefix and ask the user to choose when it is unknown.
- **FR-003**: A key MUST be checked before saving; rejected keys are not saved; unchecked keys are saved as "Nije provereno".
- **FR-004**: Users MUST be able to save any number of keys per service; duplicates are refused.
- **FR-005**: Saved keys MUST be listed with service, last 4 characters, date added and status, with "Proveri" and "Obriši" (confirmed).
- **FR-006**: Full key values MUST never be displayed after saving, logged, or stored outside the platform secure storage.
- **FR-007**: For each model, own keys of that service MUST be tried in add order, then the built-in key; pauses and rejections are tracked per key.
- **FR-008**: A key saved by an earlier version MUST be migrated into the list.
- **FR-009**: The built-in Tavli AI note and the chain test ("Probaj AI") remain on the page.

### Key Entities

- **Saved key**: id, service, secret value, date added. Status (works / rejected / unchecked) is shown but not stored as a secret.

## Success Criteria *(mandatory)*

- **SC-001**: Adding a key takes one paste and one tap for supported services.
- **SC-002**: With two own keys for a service, a rate limit on the first never stops an AI task while the second has quota (automated test).
- **SC-003**: No screen shows more than the last 4 characters of a saved key.

## Assumptions

- Supported services stay Gemini, Groq and OpenRouter; other key formats need a code change.
- Key prefixes are stable public formats of those services.
