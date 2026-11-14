# Product delivery plan — accepted revision

Source: owner's “Tavli revizija ideja i inicijalni plan”, dated 12–13 November
2026. This is the normalized English plan; see [review findings](development/review-2026-11-13.md).
Later explicit decisions override older recommendations in the source. Existing
visual design and architecture stay; features below are not automatically implemented.

## Delivery sequence

Phases describe dependencies, not fixed-duration sprints. Household work can
start in phase 2 without waiting for catalog contents. Exact assignments and
87 source tasks are in the [delivery register](../specs/011-team-development/contracts/delivery-backlog.md).

| Phase | Deliverables | Exit evidence |
| --- | --- | --- |
| 1 — foundations | Close open auth/shopping defects; agree food, AI and member-input contracts; strict AI validation; image-through-gateway spike then server credentials; dates without zone; kitchen measures; split shopping repository; meal tags/snacks/list-based slots/rules; five-tab Home shell and UI standard | Producer contracts merged; local checks; current auth/deep links and quantity ledger preserved |
| 2 — catalog + household | Foods/aliases/conversions/overrides; 300–400 reviewed foods; attributed nutrition; one matcher; existing recipe mapping; unresolved UI; catalog-ready AI ingredients; preferences; invitations/roles; Home, cooking and add-to-plan | Catalog identity/download/mapping tests; two-household isolation; an accepted vertical slice per domain |
| 3 — catalog consumers | Shopping by food/unit; approximate/unknown amounts; pantry coverage; calories per portion; no-step meals; allergen-safe plans and favorites; member allergies/favorites; realtime; pantry CRUD, explicit transfer, consume/undo | No duplicated supply or intake; restriction validation; offline replay, reversal and account-switch tests |
| 4 — extensions | Store-price import and basket estimate; receipt QR spike; cookbook RAG; private intake/targets and ratings; voice draft agent; Windows; calorie strip; real website download links | Separate spikes and implementation slices; privacy/source terms; actual platform smoke evidence |
| 5 — cycle | Explicit consent, secure device-only dates, optional generic dietary hints and local indicator | No raw cycle data in sync/export/AI; stale-data/disable/delete tests |
| 6 — imported plans | Image/text first, PDF/alternatives/repeat later; catalog mapping; explicit diary/target/allergen integration; capture/crop | Review before save; original text/exact grams; locked meals; explicit upload retention |

Dev 1: umilutinovic25 (catalog/shopping); Dev 2: Ceviz (AI/planning);
Dev 3: Matija (people/household); Dev 4: Anja (everyday UI/platforms).
This keeps current assignments; it does not establish equal workload.
Estimate remaining implementation, tests and integration per phase before rebalancing.

## Cross-phase requirements

- Keep ingredients embedded in recipe snapshots with optional `food_id` and
  original text. Stable UUID and readable slug are separate; aliases mean the
  same ingredient, never a substitute. Uncertain mapping remains visible.
- General measures and ingredient/household overrides share a versioned contract.
  Exact dimensions and approximate density/piece conversions are distinguished.
  Integer micros avoid repeated rounding. Preserve existing source allocations.
- CivilDate exists in domain code; SQL calendar-day columns will become `date`,
  while actual instants stay UTC timestamps. Coordinate schema merges rather
  than requiring all unrelated foundation changes in one giant migration.
- One operation identity links purchase/receipt, cooked consumption and reversal.
  No duplicate receipts, negative stock or duplicated intake on reconnect.
  “Cooked” is not proof every member ate. Transfer is an explicit action.
- Household data uses existing repositories/outbox. Shared reference catalog
  downloads; household additions upload. Credentials/cycle dates never sync.
- Cookbooks, voice and import use the same validated draft/matcher/approval path.
  Future formats need compatible seams now, not speculative unused tables.
- Home is central in five tabs. Pantry presence means available, quantity optional,
  no expiry UX; known quantity is consumed on cooking and restored on undo.
  Unknown stock remains until removed. Retiring legacy columns needs a later
  migration/data-preservation decision, not a document edit.
- Nutrition tracking is optional/off by default, no sixth tab; values come from
  reviewed sources, not AI guesses. Goals: “Samo pratim”, “Ručno”, optional
  “Kalkulator”. Private diary, attributed method and completeness/coverage.
- Cookbook RAG is private to the household, cites book/page, processes bounded
  resumable jobs and preserves storage/retrieval authorization. Voice is
  press-to-talk with allowlisted commands against a draft and Serbian speech.
- Cycle dates stay in secure device storage; only an explicit optional generic
  dietary hint enters AI. No health promises. Imported nutritionist meals retain
  exact text/grams and are protected from AI regeneration.

## Feature preparation register

008/009 and all product feature groups now have draft specs. 010 remains partially
implemented; 011 standardizes development, 012 security, 013 testing and 033 release
operations. See [full spec index](../specs/README.md) and
[source-task mapping](development/source-task-map.md). Reserve new numbers after
033 through a registry PR. Prepared specs do not imply completed implementation.

| Feature key | Owner | Prerequisites | Decisions before implementation |
| --- | --- | --- | --- |
| AI-SCHEMA | Dev 2 | Existing AIRouter/task parsers | Schema versions, closed enums, domain validation, repair budget |
| AI-GATEWAY | Dev 2 | Auth, image-timeout spike | Allowed tasks, quota, size/timeouts, cancel/retry ownership, key cutover |
| DATES | Dev 1 | CivilDate, schema coordination | Old-client serialization and upgrade path |
| UNITS | Dev 1 | Existing shopping demand | Defaults, approximation and override precedence |
| CATALOG | Dev 1 | Date/unit contracts | UUID/slug, alias scope, seed review, nutrition provenance/licenses |
| HOUSEHOLD (008) | Dev 3 | Auth/member contract | Inviting rights, transfer/leave semantics, purpose-limited personal aggregates |
| REALTIME (009) | Dev 3 | Household transitions | Authorized invalidation/reconnect/conflicts |
| MEAL-RULES | Dev 2 | AI schema/member aggregate | Snack identity, suitability/intensity/kind enums, favorites aggregation |
| SHOPPING-FOODS | Dev 1 | Catalog/supply contract | Dictionary versions, legacy snapshots and conversions |
| EVERYDAY-UX | Dev 4 | Routes/cooking operation | Home route/order, existing-route compatibility |
| PANTRY | Dev 4 | Catalog, supply/cooking contract | Known/unknown quantity, explicit transfer, reversible consumption |
| NUTRITION | Dev 1 calculation; Dev 3 diary; Dev 2/4 consumers | Catalog provenance | Reference terms, seven source-proposal questions, intake/goal semantics |
| PRICES | Dev 1 | Catalog/matching | Source coverage/date, price unit, schedule and attribution |
| RECEIPT-QR | Dev 1 | Catalog | Time-boxed spike: available data, permitted access, mapping and retention |
| COOKBOOKS | Dev 2 | Gateway/storage authorization | Text PDF/EPUB vs OCR, quotas/jobs, embeddings, rights/deletion |
| VOICE | Dev 4; Dev 2 gateway | Gateway/catalog | Recording retention, STT, command schema, Serbian speech on each target |
| WINDOWS | Dev 4 | Plugin audit | Secure store, deep links/auth, file picker, wake lock, CI/hardware |
| CYCLE | Dev 3, Dev 2 hints, Dev 4 indicator | Preferences/hint boundary | Consent, stale rules, six source-proposal questions |
| PLAN-IMPORT | Dev 2; Dev 1/3/4 consumers | Slots/catalog/nutrition | Ten source-proposal questions, crop/retention, exact quantities/alternatives |
| UI-PACKAGE | Dev 4; deferred | Current UI standard | Explicit team start, six source questions and verified external repo access |

## Decisions still required

The linked Claude proposals were not supplied in full. Counts of seven/ten/six
questions above are source references, not questions invented or resolved here.
Retrieve them or clarify explicit requirements before the affected feature starts.

1. Creator-only versus all-member favorites: recommendation is all diners,
   but no broad access to private profiles/diaries is approved by inference.
2. Initial cookbook real-text PDF/EPUB versus scanned OCR.
3. Allergen vocabulary: reviewed canonical codes, distinct lactose avoidance
   and dietary preferences; do not turn a draft label into a medical claim.
4. Source/license approval for nutrition values and prices, receipt feasibility,
   permitted retention, device speech quality and actual Edge image timeout.
5. Legacy expiry data removal is separate; expiry UX is excluded now.
6. External requirements: store URLs, Windows hardware, Apple enrollment,
   GitHub ruleset availability and four reviewers' verified GitHub handles.

Word/Excel/share-sheet import and Apple Health/Health Connect are later additions,
not silent expansion of the 87 imported tickets. The external `tavli_ui` package
waits for team agreement; consistent components apply now in existing folders.

## Cross-cutting security work — added after source review

[012 Security baseline](../specs/012-security-baseline/spec.md) adds remediation
and verification across phases; it is separate from the original 87-task import.
Prioritize photo-path containment, safe errors, gateway credential cutover and
same-SHA SQL/function deployment gates. Device/environment isolation and storage
protection gate diary/cycle rollout; membership and private retrieval tests gate
household/RAG release. Dev 3 leads, with Dev 1 data, Dev 2 AI and Dev 4 platform
owners. The [security matrix](../specs/012-security-baseline/contracts/security-test-matrix.md)
requires concrete evidence; none of these fixes is claimed implemented here.

## Concrete source decisions retained for feature specifications

- Kitchen defaults: glass 200 ml, cup 250 ml, tablespoon 15 ml, teaspoon 5 ml.
  Exact same-dimension conversion differs from approximate density/piece conversion;
  show “~” automatically for approximation and “Proveri količinu” when unsupported.
- Catalog target: shared and household foods in `foods` with nullable household
  ownership, separate aliases/units/household overrides; density, piece weight and
  usual package support conversion. UUID is identity; slug is readable. Yogurt
  fat-percentage variants may share identity under reviewed rules; flour T-400
  and T-500 remain distinct. Never merge different foods merely by similarity.
- Meal defaults: lunch medium/hearty and cooked/roast; dinner light/medium;
  at most one hearty meal daily and no repeated dish kind on consecutive days.
  Household can change these defaults. Snacks are light without cooked dishes.
  Locked imported meals are never rewritten; allergen conflicts remain visible
  for review instead of silently altering a prescribed meal.
- Optional diary source behavior: when tracking is enabled, “Skuvano” records a
  portion for the actor; other members explicitly confirm “Jela sam”. Allow
  correction/undo; this must never create intake for every household member.
- Cycle hints stop seven days after expected onset without confirmation, until
  refreshed. Only the person generating the plan can opt into her device's hint.
- Imported nutritionist originals are not retained. Specify transient processing
  cleanup and provider retention; exact grams and original text survive review.

## Complete specification set — 2026-11-14

The owner requested all required specs before a single documentation commit.
The [spec index](../specs/README.md) and [source mapping](development/source-task-map.md)
now cover every source task. Testing 013 covers deterministic unit/widget/local
backend/device evidence, and release 033 covers signing, environments, compatibility,
monitoring and recovery. Implementations/hosted settings remain separate work.
Clarification gates stay explicit instead of invented estimates, schemas or approvals.
