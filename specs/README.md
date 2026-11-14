# Spec Kit index and delivery status

Updated 2026-11-14. All engineering documents are English; UI copy is Serbian Latin.
This branch prepares the complete agreed roadmap through 033. A draft spec is
not implementation, accepted architecture detail or release evidence.
See [documentation index](../docs/README.md) and [product plan](../docs/product-plan.md).

| Spec | Lead | Status |
| --- | --- | --- |
| [001-foundation-ai-router](001-foundation-ai-router/spec.md) | Team | Historical baseline; preserve acceptance evidence |
| [002-builtin-ai-keys](002-builtin-ai-keys/spec.md) | Team | Historical baseline; preserve acceptance evidence |
| [003-recipe-screens](003-recipe-screens/spec.md) | Team | Historical baseline; preserve acceptance evidence |
| [004-ai-keys-list](004-ai-keys-list/spec.md) | Team | Historical baseline; preserve acceptance evidence |
| [005-themes-animations](005-themes-animations/spec.md) | Team | Historical baseline; preserve acceptance evidence |
| [006-account-login](006-account-login/spec.md) | Team | Historical baseline; preserve acceptance evidence |
| [007-keep-screen-on](007-keep-screen-on/spec.md) | Team | Historical baseline; preserve acceptance evidence |
| [008-household-members](008-household-members/spec.md) | Dev 3 | Draft; resolve recorded questions before dependent implementation |
| [009-household-realtime](009-household-realtime/spec.md) | Dev 3 | Draft; resolve recorded questions before dependent implementation |
| [010-plan-and-shopping](010-plan-and-shopping/spec.md) | Team | Partially implemented; read [direction overlay](010-plan-and-shopping/current-direction.md) |
| [011-team-development](011-team-development/spec.md) | Team | Documentation prepared; independent review pending |
| [012-security-baseline](012-security-baseline/spec.md) | Team | Draft; resolve recorded questions before dependent implementation |
| [013-testing-strategy](013-testing-strategy/spec.md) | Team | Draft; resolve recorded questions before dependent implementation |
| [014-ai-response-contracts](014-ai-response-contracts/spec.md) | Dev 2 | Draft; resolve recorded questions before dependent implementation |
| [015-ai-server-gateway](015-ai-server-gateway/spec.md) | Dev 2 | Draft; resolve recorded questions before dependent implementation |
| [016-calendar-date-storage](016-calendar-date-storage/spec.md) | Dev 1 | Draft; resolve recorded questions before dependent implementation |
| [017-kitchen-unit-conversion](017-kitchen-unit-conversion/spec.md) | Dev 1 | Draft; resolve recorded questions before dependent implementation |
| [018-ingredient-catalog](018-ingredient-catalog/spec.md) | Dev 1 | Draft; resolve recorded questions before dependent implementation |
| [019-meal-selection-rules](019-meal-selection-rules/spec.md) | Dev 2 | Draft; resolve recorded questions before dependent implementation |
| [020-catalog-shopping](020-catalog-shopping/spec.md) | Dev 1 | Draft; resolve recorded questions before dependent implementation |
| [021-home-and-cooking](021-home-and-cooking/spec.md) | Dev 4 | Draft; resolve recorded questions before dependent implementation |
| [022-simple-pantry](022-simple-pantry/spec.md) | Dev 4 | Draft; resolve recorded questions before dependent implementation |
| [023-optional-nutrition](023-optional-nutrition/spec.md) | Dev 3 | Draft; resolve recorded questions before dependent implementation |
| [024-store-prices](024-store-prices/spec.md) | Dev 1 | Draft; resolve recorded questions before dependent implementation |
| [025-receipt-qr-spike](025-receipt-qr-spike/spec.md) | Dev 1 | Draft; resolve recorded questions before dependent implementation |
| [026-cookbook-library](026-cookbook-library/spec.md) | Dev 2 | Draft; resolve recorded questions before dependent implementation |
| [027-voice-recipe-agent](027-voice-recipe-agent/spec.md) | Dev 4 | Draft; resolve recorded questions before dependent implementation |
| [028-windows-support](028-windows-support/spec.md) | Dev 4 | Draft; resolve recorded questions before dependent implementation |
| [029-private-cycle-hints](029-private-cycle-hints/spec.md) | Dev 3 | Draft; resolve recorded questions before dependent implementation |
| [030-nutritionist-plan-import](030-nutritionist-plan-import/spec.md) | Dev 2 | Draft; resolve recorded questions before dependent implementation |
| [031-external-ui-library](031-external-ui-library/spec.md) | Dev 4 | Draft; resolve recorded questions before dependent implementation |
| [032-website-downloads](032-website-downloads/spec.md) | Dev 4 | Draft; resolve recorded questions before dependent implementation |
| [033-release-operations](033-release-operations/spec.md) | Dev 3 | Draft; resolve recorded questions before dependent implementation |

## How to use this set

1. Pick the source card in the [87-task mapping](../docs/development/source-task-map.md).
   Read its spec, plan, tasks, dependencies and readiness checklist. Every source
   task retains its role and phase; no reassignment or completion is inferred.
2. Confirm current code, exact affected files, remaining effort, reviewer and
   open questions. Drafts become Ready only after dependent contracts, data-model/
   migration design and Serbian UI copy are settled. Research can proceed separately.
3. Implement slices on branches from current origin/dev in existing checkouts; PRs
   target dev. Consumer branches wait for producer contracts to merge. No stacking.
4. Set SPECIFY_FEATURE_DIRECTORY per session. The installed script prepares files,
   not Git branches; its get_feature_paths also persists the local feature pointer.
   Inspect that diff and don't commit incidental context or overwrite others' edits.
5. Follow 012 security, 013 testing and 033 release gates. Actual checks, independent
   review and integration evidence determine Done; draft documents do not.

## Number allocation and historical scope

001–033 are allocated in this revision. Reserve the next number (currently 034)
with a small registry PR before parallel creation; local auto-numbering cannot
prevent collisions across four agents. Existing 001–007 evidence is preserved;
010 has a dated overlay and its original checkmarks. Never rewrite history to
pretend a later design already shipped.

008/009 cover the previously reserved household/realtime scope. 011 is team
standardization, 012 security, 013 test infrastructure. 014–032 cover the product
feature groups and website handoff, and 033 covers collaboration/release operations.
New feature specs have requirements, concrete scenarios, data/privacy boundaries,
file/contract plans, owner tasks and readiness gates. Open external/source questions
are explicit; do not generate speculative schema or pretend a missing decision
was approved. Apple/Google login and Health integrations remain later options,
not silently expanded scope beyond the accepted plan.
