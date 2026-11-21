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

The 2026-11-20 direction agreed with Matija (Dev 3) supersedes the original
invitation behavior in [Trello #58](https://trello.com/c/lkL6PzXU),
[#59](https://trello.com/c/zshRjGSY) and [#60](https://trello.com/c/GX84OkvD).
The ticket IDs and original assignment are retained for traceability.

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

- **FR-101**: The current owner can share one reusable invite credential per household as a link, QR payload or a manually entered code. New credentials have twelve random characters from an alphabet of 32 symbols. Display three groups of four. Manual entry accepts lowercase, spaces and hyphens. The in-app QR scanner reads the same code. The configured Supabase project hosts the HTTPS redirect. App links, QR and manual entry converge on the same authenticated preview and explicit confirmation. The preview reveals the destination name and whether the caller is the last member of their source household. The invite has no scheduled expiry, owner-facing deactivation, recipient binding, active invites list, join request or owner approval. It is unavailable once the destination household is deleted.
- **FR-102**: Show the destination household name before changing membership. The existing membership, including the personal household provisioned for a new account, is the source. If source and destination differ, ask whether to leave and offer “Da, ponesi moje recepte”, “Da, bez recepata” and “Ne, ostani ovde”. Either affirmative choice joins as a member and leaves the source in one server transition. The first copies recipes created by the departing user and legacy recipes with no known creator, including eligible content from a solo household before deletion. Each copy is independent. When members remain, the originals stay in the source. The second option copies zero recipes. Plans, shopping and pantry do not transfer. Cancel leaves both households untouched. Opening the link of the current household causes no transition.
- **FR-103**: A departing owner automatically hands ownership to the longest-serving remaining member, ordered by the earliest membership join time and then by ascending user UUID to break ties. Before the last member leaves, show an explicit permanent-deletion warning and require acknowledgement as part of the switch. After confirmation and any selected recipe copies, delete the empty household and its remaining shared data, including recipes, plans, shopping, pantry and source photo objects. Its link stops working. Personal account data retains its existing access and lifecycle. The owner can remove a member through the member-management slice. Removal ends access under the old membership; under the current bearer-link rule, a removed user who still has the link can join again.
- **FR-104**: Each person chooses tastes, structured allergens, favorites and recipe ratings. Same-household membership does not grant broad access to private records.
- **FR-105**: Preserve existing email-code/name/confirmation flow and close confirmed defects with regression tests; use canonical reviewed allergen/avoidance vocabulary.

## User scenarios and acceptance

- **US1 / SC-001**: A valid shared link, scanned code or manually entered code previews the destination name and the caller’s own switch consequences before confirmation. Invalid tokens, unavailable households and unauthenticated callers cannot join. Cancel and opening one's own household link leave data unchanged. Two eligible accounts can independently join through the same link.
- **US1 / SC-004**: Each affirmative choice results in exactly one membership. The recipe choice applies only to eligible recipes; the other choice transfers none. The source's plan, shopping and pantry are absent from the destination. Departure of an owner promotes the longest-serving remaining member. A last-member switch without acknowledgement, or one that became a last-member switch after preview, leaves the source intact. With the warning acknowledged, the source and its remaining shared data are deleted and its link becomes unavailable. Failed or repeated transitions cannot partially move data, duplicate copies or leave the user without a membership.
- **US1 / SC-005**: An offline or stale client cannot apply a household switch using an outdated source or replay source writes into the destination. After a lost response it can reconcile with the server and retry safely.
- **US2 / SC-002**: A removed member reconnects with queued writes: server denies old-household access; another member retains shared data.
- **US3 / SC-003**: Two co-members can share recipes but cannot read each other's diary or personal settings outside the agreed planning aggregate.

Include empty/error/offline/cancel/retry, repeated action and ownership transitions
where applicable. Use deterministic fixtures and observable state assertions;
security denials require allowed-case controls as well. Acceptance is unverified
until execution evidence is linked.

## Data and privacy

- Privacy: the preview reveals only the destination name from the target household to a signed-in bearer. Server-owned
  membership and RLS govern household data. Personal preferences, allergens,
  favorites, ratings and diary data retain their personal access rules.
- Abuse: a forwarded link allows repeated joins by signed-in bearers. Use an
  opaque random token, server-side rate limits and generic failures. Member
  removal ends access at the server. A separate ban or blocklist is outside
  the agreed flow.
- Credentials: keep the invite token out of diagnostics, analytics, public
  table reads and the sync payload. No new provider credential or AI work.
- Files: eligible recipe photos and snapshots require copies under verified
  private destination paths. Source objects for an empty household are deleted
  after the membership transition commits.
- Deployment: migrations and verification follow 012/013 with synthetic
  accounts. Hosted controls remain unverified.

## Exact UI copy carried forward

“Domaćinstvo”, “Pozovi člana”, “Pridruži se”, “Ukusi i sklonosti”, “Omiljeni”.

Switch confirmation: “Da li ste sigurni da želite da napustite domaćinstvo?”
Actions: “Da, ponesi moje recepte”, “Da, bez recepata”, “Ne, ostani ovde”.
Last-member warning: “Poslednji ste član ovog domaćinstva. Ako odete, domaćinstvo i podaci koji ostanu u njemu biće trajno obrisani.” Show the destination name and explain which recipes will be copied before confirmation. Finalize additional screen and error copy in Serbian Latin before the UI task becomes Ready.

## Dependencies and open decisions

Producer specs: Existing baseline; no new producer feature required for the first slice.

- **Q1, resolved for direct join by Matija (Dev 3), 2026-11-20**: Copy
  caller-created and unknown-creator recipes when requested, promote the
  longest-serving remaining member, and permanently delete an empty source
  after warning and acknowledgement. Dev 1 reviews the technical contract,
  standalone leave/removal behavior and offline compatibility separately.
- **Q2** (Dev 3 with reviewer): Creator-only versus participating-members favorites aggregation remains open; clarify purpose/consent and allergy vocabulary.

Unresolved questions block their dependent code, not independent research/tests.
Do not invent answers to linked proposals that were not provided. Before Ready,
record decision owner/date, precise typed contract and reviewed acceptance fixtures.
