# Producer/consumer contracts before parallel implementation

Status: contract acceptance checklist, not implemented API signatures. Keep
current folder/layer boundaries; add concrete types under existing domain/data/
feature directories only in the owning feature's accepted plan.

Every contract records version, owner, consumers, example fixtures, failure and
retry behavior, data scope, compatibility and producing PR. A breaking change
requires consumer review and migration; adding a new field is not automatically
compatible if parsers enforce a closed schema. Preserve legacy snapshots with
explicit version adapters, never silently reinterpret stored quantities.

## C1 — ingredient identity/matching (Dev 1 → Dev 2/3/4)

Stable UUID + readable slug, name, category, base unit; exact same-food aliases;
ingredient/household conversions and provenance. Input keeps original text.
Result distinguishes matched, unresolved and proposed mapping. Define exact/
normalized/candidate/AI-assisted matching priority and confidence/review rules.
AI cannot create trusted aliases or canonical foods without the approved path.
One matcher serves all inputs. Fixtures: inflections, similar-but-distinct food,
unknown name, user override, repeated/offline backfill and idempotent retries.

## C2 — AI recipe/plan and gateway (Dev 2 → all)

One schema per task: required fields/types, closed quantities/units/meal enums,
bounds, unknown handling, no-step meal validity and recipe/plan versioning.
Parsers validate semantics after JSON decoding. Ingredient mapping follows C1.
Drafts do not persist before review. Fixtures cover malformed/extra/missing data,
unsupported enums, locked/snack slots, duplicate/omitted meals and cancellation.

Gateway: authenticated user, allowed task/provider configuration, size/token/time
budget, bounded repair/fallback responsibility, request identity, cancellation,
quota/retry-after and safe Serbian error mapping. Built-in secrets never return
to the app. Bring-your-own keys keep the existing secure path. Image-timeout
spike precedes choosing synchronous versus queued processing.

## C3 — member inputs/privacy (Dev 3 → Dev 2/1/4)

Explicitly define the minimum planning view of participating members' allergies,
preferences and favorites; no broad household SELECT of private diary/profile
rows. Keep allergy/avoidance vocabulary reviewed. Define active household, consent,
member leave/removal, invite expiry/revoke/join and offline queue transitions.
Favorites aggregation is unresolved, not guessed by a consumer. Two-account and
two-household fixtures include both allowed and forbidden operations.

## C4 — pantry/shopping supply (Dev 1 ↔ Dev 4)

Specify known/unknown presence, exact/approximate/unsupported units, allocation
priority across all plan/recipe sources and one shared receipt identity. Keep
integer micros, source snapshots and bought/manual history. Explicit “Prebaci u
ostavu” is idempotent and does not credit the purchase twice. Unknown presence
requires checking, never complete quantified coverage by assumption.

Fixture: demand 300 g, stock 100 g, purchase 200 g; transfer adds no new coverage;
increased demand 400 g requires 100 g more. Include repeated transfer, deletion,
partial quantity, offline replay, concurrency and undo across ownership scope.

## C5 — cooked/undo operation (Dev 4 → Dev 1/3)

Do not invent an unrelated global event bus. Define one repository/service
operation using stable operation/entry/version identity, approved recipe snapshot,
servings, actor and cooked/undone state. Dev 1 handles shopping demand; Dev 4
handles known pantry consumption; Dev 3 handles the actor's optional intake.
Agree transactional boundaries or a replay-safe reconciliation/outbox design
before implementing three independent side effects. Replays are no-ops; reversal
is linked to the original operation, bounded and repeatable. Zero-floor conflicts
and edited/deleted ingredients have explicit behavior. Other members confirm
their intake independently; cooking does not write their private diaries.

## C6 — nutrition/source and strip (Dev 1 → Dev 2/3; Dev 3 → Dev 4)

Reference values per 100 g with source/version/date and missing-data state;
calculation per portion includes coverage and approximation. AI maps references,
never invents nutrient numbers. Unknown mass/units do not become zero nutrition.
Dev 3 provides private diary/goal access and a calorie-strip component consumed
by Home. Define hide-calories, opt-out, manual target import consent and repeated
intake/undo. No personal targets/data leak through household sync or AI logs.

## C7 — routes/components/platforms (Dev 4 → all)

Preserve existing deep links/auth redirects. Define Home route and initial tab,
stable week/month action placement, adaptive component behavior and keyboard/
permission/lifecycle cleanup. Use current theme/animation layer and feature
providers. Existing routes/wake-lock behavior have regression tests. Windows
remains planned until plugin audit, target, build and real-machine proof exist.

## C8 — future documents/voice/import (Dev 2 + Dev 4 + data owners)

Untrusted input cannot execute instructions or arbitrary actions. RAG retrieval
must authorize household/book/chunk with page provenance and delete derivatives
with originals. Voice commands are allowlisted against a draft with cancel and
review. Imported nutritionist plans preserve original text/exact grams, review
uncertainty, lock meals and define file retention/cropping. All three use C1/C2,
not a second parser, matcher or direct database path.

## C9 — device-only cycle exception (Dev 3 → Dev 2/4)

Explicit consent, secure local dates, owner/device isolation, expiry of stale
input, deletion and disable behavior. No raw dates or phase in server/sync/export/
analytics/AI requests. Only explicitly enabled generic dietary hints for the
person generating a plan; allergies and locked meals win. No hidden medical
inference or external health integration in the first slice.
