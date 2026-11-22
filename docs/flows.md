# Flow map: how features hand data to each other

Status: maintained overview. It lists every handoff between user flows, the
contract that defines it and how far that contract is. Update the row in the
same PR that adds or changes a contract. Detailed acceptance rules stay in the
linked contracts and in the
[shared contract checklist](../specs/011-team-development/contracts/shared-boundaries.md).

## The main journey

```text
Sign-in / household
        │ account and household scope
        ▼
Recipes ──────────────► Plan ──────────► Nabavka ──────────► Ostava
  │  approved recipe       approved plan     checked purchase      ▲
  │  snapshot              and entries       "Prebaci u ostavu"    │ known quantities
  │                           │                                    │ consumed once
  └──── "Po receptu" ────────►│ (standalone recipe shopping)       │
                              ▼                                    │
                    Početna / Plan meal ──► Kuvanje ──► Skuvano ───┘
                                                          │
                                                          └──► Nutrition diary
                                                               (cook only, optional)
```

The Nabavka screen has two modes, "Po planu" and "Po receptu"; both share the
household's supply and allocations. Cooking never requires a plan, and the
first useful plan or recipe shopping never requires pantry or profile setup.

## Handoffs

Status: **agreed** = reviewed contract on `dev`; **draft** = written but not
accepted; **missing** = only requirements or open questions exist.

| From → to | What passes | Contract | Status | Owner |
| --- | --- | --- | --- | --- |
| Sign-in → all flows | Account, session, household scope, sync outbox | [account app interfaces](../specs/006-account-login/contracts/app-interfaces.md), [server schema](../specs/006-account-login/contracts/server-schema.md) | agreed, implemented | Dev 3 |
| Household members → Plan | Minimum planning view of members' allergies, preferences, favorites; invite/leave transitions | C3 checklist in shared contracts; open questions in [008](../specs/008-household-members/spec.md) | missing | Dev 3 |
| AI → Recipes, Plan | Validated recipe and plan responses; gateway requests and errors | [AI response contract](../specs/014-ai-response-contracts/contracts/ai-response-contract.md), [AI gateway contract](../specs/015-ai-server-gateway/contracts/ai-gateway-contract.md) | draft | Dev 2 |
| Recipes → Plan | Recipe identity and snapshot; meal slots and recipe labels | [recipe repository](../specs/003-recipe-screens/contracts/recipe-repository.md); [meal slots](../specs/019-meal-selection-rules/contracts/meal-slots-contract.md), [recipe labels](../specs/019-meal-selection-rules/contracts/recipe-labels-contract.md) | repository agreed; slots and labels draft | Dev 2 |
| Ingredient identity → Nabavka, Ostava, nutrition | Food identity, aliases, units and conversions | C1 checklist; [kitchen measures proposal](../specs/017-kitchen-unit-conversion/measure-contract-proposal.md); catalog model on branch `docs/catalog-model-contract` (not merged) | draft | Dev 1 |
| Plan → Nabavka | Approved entries and servings become demand; reconcile only the difference; cooked entries stop demand | [plan and shopping interfaces](../specs/010-plan-and-shopping/contracts/app-interfaces.md) (Planning; Shopping and supply) | agreed (010), partly implemented | Dev 1 |
| Recipe → Nabavka ("Po receptu") | Recipe snapshot, servings and "have" choices as a shopping source without a plan | same file, Standalone recipe shopping | agreed (010) | Dev 1 |
| Nabavka → Ostava | Checked purchase moves once via "Prebaci u ostavu"; one supply identity, no double coverage | same file (`receivePurchase`); C4 checklist; [022](../specs/022-simple-pantry/spec.md) | missing (requirements only, no typed contract) | Dev 1 ↔ Dev 4 |
| Početna / Plan → Skuvano | One cooked/undo operation for a plan entry or recipe | cooked meal contract (`specs/021-home-and-cooking/contracts/cooked-meal-contract.md`, added in its own PR) | draft | Dev 4 |
| Skuvano → Ostava | Known quantities consumed once as a ledger; undo restores once; manual count wins | cooked meal contract | draft | Dev 4 |
| Skuvano → Nutrition diary | Optional intake for the cook only; other members confirm their own | cooked meal contract; C6 checklist; [023](../specs/023-optional-nutrition/spec.md) | draft | Dev 3 |
| Ratings → Recipes | Current personal rating; household-visible average and count only | [recipe ratings](../specs/008-household-members/contracts/recipe-ratings.md) | draft | Dev 3 |
| Orthodox calendar → Početna, Plan | Dietary rule per civil date, including time restrictions, and current or next named fast | calendar API in [035 plan](../specs/035-fasting-holidays/plan.md) | missing | Dev 2 |
| Fasting knowledge base → AI gateway | Retrieved calendar facts and passages, server-validated `fasting_question` answers with sources | [035](../specs/035-fasting-holidays/spec.md) FR-002/FR-003 and [proposed gateway extension](../specs/015-ai-server-gateway/contracts/ai-gateway-contract.md#proposed-extension-for-spec-035) | draft | Dev 2 |
| Household “Pratim post” → Plan | Default fasting scope and strictness with an explicit per-plan override | [035](../specs/035-fasting-holidays/spec.md) FR-005/FR-006 | missing | Dev 3 → Dev 2 |
| Screens ↔ routes | Tab order, Home route, deep links, return routes | [010 navigation table](../specs/010-plan-and-shopping/contracts/app-interfaces.md); [UI standard](development/ui-standard.md); C7 checklist | partly agreed; Home route open in [021](../specs/021-home-and-cooking/spec.md) | Dev 4 |

## Missing contracts to write next

1. **Nabavka → Ostava**: typed `receivePurchase` contract with fixtures
   (repeated transfer, offline replay, undo purchase after transfer).
2. **Household → Plan**: minimum member planning view, consent and leave/remove
   transitions.
3. **Ingredient identity**: merge the catalog model and kitchen measure proposals
   so shopping, pantry and nutrition use one matcher.

## Rules for every handoff

- The producer writes the contract under its spec's `contracts/` folder before
  consumer code. Consumers wait for it to merge instead of stacking branches.
- A contract names version, owner, consumers, fixtures, failure/retry and undo
  behavior, data scope and compatibility (see the shared contract checklist).
- Replays are no-ops and undo is linked to the original operation.
- Personal data (diary, cycle, private profile) never travels through household
  rows, AI requests or logs.
