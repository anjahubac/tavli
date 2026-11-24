# Feature Specification: AI keys list

**Feature Branch**: `004-ai-keys-list`

**Created**: 2026-10-30

**Status**: Implemented

**Input**: User description (Serbian, translated): "I want the API keys page changed: one field for adding an API key (any key, so don't put 'Gemini API ključ' or similar in the field label) and the ability to add more than one; below it an overview of the API keys the user has already added (if any)."

> All UI text is Serbian (Latin script). Quoted strings are the exact UI copy.

## Clarifications

### Session 2026-10-30

The owner was away; these answers are the recommended defaults, taken so work could continue.

- Q: How does the app know which service a key belongs to? → A: From one service list (see Service list below). The key's prefix is looked up in it as soon as the key is pasted, and "Prepoznat servis: <ime>" is shown. There is no service picker and no field for a key name. If the prefix is not in the list (a service without a stable prefix, or one we do not support), "Servis nije prepoznat. Podržani su: …" is shown and "Dodaj ključ" stays disabled.
- Q: Is a key checked before it is saved? → A: Yes, with the free model-list request. A rejected key is not saved. If the check cannot run (no network), the key is saved and marked "Nije provereno".
- Q: Several keys for the same service — in what order are they used? → A: In the order they were added; each key has its own rate-limit pauses, so when one key's free limit runs out the next key of the same service is tried before the built-in Tavli access.
- Q: How is a saved key shown? → A: Service name, the last 4 characters ("••••a1B2"), date added and status. The full key is never shown again.
- Q: Should the page mention the built-in Tavli keys? → A: No (owner, 2026-10-30; since 2026-11-23 the notice and the order help text say they come last). The page shows only keys the user added; built-in keys work silently in the background. This replaces spec 002 FR-006's "Koristi se ugrađeni Tavli AI" note.
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
2. **Given** a key whose prefix is not in the service list, **Then** "Servis nije prepoznat. Podržani su: Gemini, Groq, OpenRouter, OpenAI." is shown and "Dodaj ključ" stays disabled. Nothing is saved or sent to any service.
   **And given** a recognized key (e.g. `sk-proj-…`), **Then** "Prepoznat servis: OpenAI" is shown under the field as soon as it is pasted.
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
4. **Given** built-in keys and no own keys, **Then** the list says "Još nema dodatih ključeva." and no built-in key is listed.

---

### User Story 3 - More keys mean more free quota (Priority: P2)

When one key of a service hits its free limit, the same model is tried with the
person's next key of that service before moving to the next model. Built-in
access comes after all own keys.

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
- **FR-002**: The app MUST detect the service from the key prefix in the service list. When it is unknown, the app MUST say which services are supported and MUST NOT save or send the key.
- **FR-003**: A key MUST be checked before saving; rejected keys are not saved; unchecked keys are saved as "Nije provereno".
- **FR-004**: Users MUST be able to save any number of keys per service; duplicates are refused.
- **FR-005**: Saved keys MUST be listed with service, last 4 characters, date added and status, with "Proveri" and "Obriši" (confirmed).
- **FR-006**: Full key values MUST never be displayed after saving, logged, or stored outside the platform secure storage.
- **FR-007**: For each model, own keys of that service MUST be tried in add order; all own keys come before the built-in access (see Key order); pauses and rejections are tracked per key.
- **FR-008**: A key saved by an earlier version MUST be migrated into the list.
- **FR-009**: The page MUST NOT list the built-in keys. They are mentioned only as the last step of the order (owner, 2026-11-23). The "Probaj AI" chain test section was removed at the owner's request (2026-10-30).

### Key Entities

- **Saved key**: id, service, secret value, date added. Status (works / rejected / unchecked) is shown but not stored as a secret.

## Success Criteria *(mandatory)*

- **SC-001**: Adding a key takes one paste and one tap for supported services.
- **SC-002**: With two own keys for a service, a rate limit on the first never stops an AI task while the second has quota (automated test).
- **SC-003**: No screen shows more than the last 4 characters of a saved key.

## Service list

One list in the app is the only place that says which services exist. Each entry has: display name, key prefixes, cost class (`free` or `paid`), and what the router needs to call it (address and model chain). Recognition, the "Podržani su" message, the key list and the ordering toggle all read this list, so adding a service is adding one entry.

| Service | Prefixes | Class |
| --- | --- | --- |
| Gemini | `AIza`, `AQ.` | free |
| Groq | `gsk_` | free |
| OpenRouter | `sk-or-` | free |
| OpenAI | `sk-` (checked after `sk-or-`; `sk-ant-` is not OpenAI) | paid |

Every prefix is verified against the service's official documentation before it is added to the list. As of 2026-11-23 only `sk-or-` is stated on an official page; `AIza`, `gsk_` and `sk-` are not stated there. New Gemini keys created in Google AI Studio since 2026-05-28 are a different key type; `AQ.` is their reported prefix, added by owner decision (2026-11-24) without an official page. Some reports say these keys are rejected on the OpenAI-compatible address; the check then shows the key as rejected and it is not saved. A service without a stable prefix (e.g. Mistral) is not recognized until the app has another way to tell; it is not guessed by sending the key to several services. The class is per service, so a paid plan on a service marked `free` is treated as free.

## Key order

- The person's own keys are always tried before the built-in Tavli access (gateway). This holds for free and paid keys alike.
- Among the person's own keys a toggle on the key list chooses the order: "Prvo plaćeni" (default) or "Prvo besplatni". The router keeps the model chain order inside each class. Keys of the same service stay in the order added.
- The toggle is shown only when the person has at least one paid and one free key. It is stored on this device only.
- Copy: label "Redosled", help text "Važi za tvoje ključeve. Ključevi koji dolaze uz aplikaciju uvek idu na kraju." Notice on the page: "Tavli prvo koristi tvoje ključeve, redom. Kad se njihov besplatni limit potroši, prelazi na besplatne ključeve koji dolaze uz aplikaciju."
- A paid key is billed to its owner by the service. The row of a saved key says "plaćen" or "besplatan" from the class of its service; it does not know the plan of that key.
- A personal OpenAI key uses one model named in the chain config (`gpt-6-luna`, last in both default chains; the order above moves it), because the gateway's `openai/default` is resolved on the server. Checking the key shows whether that model is available to it. It replaces `gpt-4o-mini`, which OpenAI shuts down on 2027-01-14 (owner decision, 2026-11-24, contract D6). Requests to OpenAI omit `temperature` and send `reasoning_effort: none`, the lowest effort. Not yet tried with a real key; OpenAI's pages do not state `json_object` support for this model.
- The person's keys are read from secure storage once per app run and then kept in memory, so the system asks for access at most once. Adding or deleting a key updates both. A failed read is not kept; the next use reads again. Key values never leave memory and secure storage and are never logged.

## Assumptions

- Key prefixes are stable public formats of the services in the list.
