# Specification: Household, member preferences and personal choices

**ID**: 008-household-members | **Feature key**: HOUSEHOLD
**Created**: 2026-11-14 | **Baseline**: dev 207c94c
**Status**: Draft implementation specification; decisions below gate dependent tasks.
**Lead**: Dev 3 | **Proposed independent reviewer**: Dev 1 and Dev 2

## Scope and source

Implements the HOUSEHOLD portion of the [accepted product plan](../../docs/product-plan.md).
Existing behavior is documented in [architecture](../../docs/architecture.md);
this spec does not claim the target is shipped. Preserve inherited 010 quantity,
snapshot, offline and account invariants. No new framework or folder reorganization.
Source tickets below retain original assignments/phases; the lead coordinates,
not reassigns them. No additional feature is authorized merely by a technical seam.

## Requirements and source traceability

- **FR-001**: Deliver **Agree the member-input contract for planning**. Source D3-001; Dev 3; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-002**: Deliver **Complete sign-in refinements**. Source D3-002; Dev 3; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-003**: Deliver **Provide taste and preference settings**. Source D3-004; Dev 3; phase 1. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-004**: Deliver **Create invitation data and access rules**. Source D3-005; Dev 3; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-005**: Deliver **Provide household invitation UI**. Source D3-006; Dev 3; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-006**: Deliver **Join a household with confirmation**. Source D3-007; Dev 3; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-007**: Deliver **Manage household members and roles**. Source D3-008; Dev 3; phase 2. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-008**: Deliver **Choose structured allergens per member**. Source D3-009; Dev 3; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-009**: Deliver **Display allergens on ingredients and recipes**. Source D3-010; Dev 3; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-010**: Deliver **Store favorites per member**. Source D3-011; Dev 3; phase 3. Completion must satisfy the behavior and evidence below, not only code presence.
- **FR-011**: Deliver **Rate recipes**. Source D3-018; Dev 3; phase 4. Completion must satisfy the behavior and evidence below, not only code presence.

## Behavioral requirements

- **FR-101**: Invitation supports link, six-character random code and QR, expires in seven days and can be revoked; joining requires viewing household name and explicit confirmation.
- **FR-102**: Joining moves the specified recipes, never silently the old plan, shopping or pantry; define atomic membership/ownership change and queued writes before implementation.
- **FR-103**: Owner may remove a member or transfer ownership; member may leave. Last-owner and last-member behavior must be resolved before destructive operations.
- **FR-104**: Each person chooses tastes, structured allergens, favorites and recipe ratings. Same-household membership does not grant broad access to private records.
- **FR-105**: Preserve existing email-code/name/confirmation flow and close confirmed defects with regression tests; use canonical reviewed allergen/avoidance vocabulary.
- **FR-106**: Planning takes an explicit nonempty set of participating member IDs, defaulting in the UI to all current household members. Only those members' inputs contribute; unknown, foreign or removed IDs fail the whole request.
- **FR-107**: Members select canonical allergen groups, distinct from catalog foods and taste dislikes. Catalog foods carry reviewed group mappings; unresolved ingredients have unknown allergen status, never an implicit safe status.
- **FR-108**: Members may like or dislike catalog foods, the existing `DishKind` values and reviewed cuisine codes, and, in a later slice, add an optional short planning note with separate consent. These are soft preferences. No dietary-mode setting or custom style category is included.
- **FR-109**: A favorite is a personal user/recipe pair. Only selected participants' favorites for accessible household recipes contribute to planning; delete the pair when the recipe is deleted or the user loses access on leaving the household.
- **FR-110**: The planning consumer receives only the authorized aggregate of selected participants' tastes and favorite counts. Separately consented notes are added in a later slice. The server plan endpoint reads selected participants' allergen restrictions separately. Personal rows, profiles and diary entries are outside the aggregate.
- **FR-111**: Each member explicitly opts in to sharing structured preferences and favorites with household planning. A separate `planningNote` flag is enabled with the later note slice. Defaults are off, only the owner can change them, and withdrawal takes effect on server acknowledgement. The first release re-reads consent for personalized planning and keeps no aggregate cache. The server omits unshared fields; the caller's own tastes, notes and favorites are returned regardless of flags when the caller is the only participant. See the contract's Disclosure and consent section.
- **FR-112**: A request for a single other participant returns only that person's consented fields, with no name or ID. AI output is untrusted: a leak guard rejects responses that echo names, emails, notes or attributed allergies, and prompts use pseudonymous labels and are never logged.
- **FR-113**: For planning, the server plan endpoint uses the selected allergen codes present at request time to pre-filter candidates and check results. An empty selection contributes no codes and does not block planning. A profile reminder is deferred. Planning never sends member allergen selections to an AI provider, returns them to a client or logs them. The owner-only settings path handles the member's own selections; planning needs no allergen-sharing flag. Type, import-boundary, outbound-guard and canary regression tests keep it that way. See the contract's Allergen protection section.

## User scenarios and acceptance

- **US1 / SC-001**: An expired/revoked invite cannot join; a valid invite previews the household before applying exactly one membership change.
- **US2 / SC-002**: A removed member reconnects with queued writes: server denies old-household access; another member retains shared data.
- **US3 / SC-003**: Two co-members can share recipes but cannot read each other's diary or personal settings outside the agreed planning aggregate.
- **US4 / SC-004**: With two members selected, either member's allergen excludes a mapped candidate even when AI suggests it. With seven reviewed ingredients and one unresolved ingredient, automatic recommendations omit the recipe. Opening it for manual cooking shows “Mogući alergeni: nepoznata namirnica”. Selecting one member omits the other's inputs.
- **US5 / SC-005**: One member likes a food and another dislikes it; the conflict affects ranking without becoming a safety ban. A deleted recipe or departing member stops contributing favorites.
- **US6 / SC-006**: Co-members cannot read one another's raw personal settings; a foreign or removed participant ID yields no partial aggregate.
- **US7 / SC-007**: A preference or note a member has not shared never appears in another member's plan inputs, prompt or UI, for one or several participants; withdrawing consent removes it. An AI response that echoes a name, note or attributed allergy is rejected and never shown or stored.
- **US8 / SC-008**: With a member's allergen selected, no AI request, log, cache or client response contains it (canary test across all flows), and an allergenic recipe, a recipe with unresolved ingredients or a recipe outside the eligible pool cannot enter the initial personalized draft. If Dev 2 adds invented drafts later, apply the same server checks before any use.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

Household membership/invites are server-authorized; preferences, allergens, favorites and ratings are personal. Planning receives only the agreed minimum aggregate. New grants/RLS and account-scope/outbox transitions require migration and denial tests.

## Exact UI copy carried forward

“Domaćinstvo”, “Pozovi člana”, “Pridruži se”, “Ukusi i sklonosti”, “Omiljeni”, “Alergeni”, “Volim”, “Ne volim”, “Opis”, “Mogući alergeni: nepoznata namirnica”.
Additional screen/error/consent copy must be finalized in Serbian Latin before
that UI task becomes Ready. English is used for engineering documents only.

## Dependencies and open decisions

The private dish-kind slice uses the existing taste-profile storage and sync.
Later slices follow the catalog, membership and [015 gateway](../015-ai-server-gateway/spec.md)
dependencies in the [implementation plan](plan.md).

- **Q1** (Dev 3 with reviewer): Who may invite, recipe-transfer semantics for shared recipes, last-owner/leave recovery and offline transition handling?
- **Q2**: Matija decided on 2026-11-20 that selected participants contribute favorites and all household members are selected by default. Allergens are separate groups linked to users and catalog foods; dislikes remain soft. Matija decided on 2026-11-21 that planner allergen data remains server-only. Matija confirmed using the existing catalog checker codes and keeping catalog mapping review with Dev 1. Food mappings, structured taste limits, consent implementation and server integration still require coordination. See [member planning inputs contract](contracts/member-planning-inputs.md).

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
