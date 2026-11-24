# Spec Kit index and delivery status

Updated 2026-11-14; status column checked against `dev` `ebcd794` on 2026-11-24.
All engineering documents are English; UI copy is Serbian Latin.
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
| [008-household-members](008-household-members/spec.md) | Dev 3 | Built on dev (setup, invitations, join, departure, removal, ratings, tastes); allergen use in plans and acceptance pending |
| [009-household-realtime](009-household-realtime/spec.md) | Dev 3 | Built on dev (realtime signals and reconnect); acceptance evidence pending |
| [010-plan-and-shopping](010-plan-and-shopping/spec.md) | Team | Partially implemented; read [direction overlay](010-plan-and-shopping/current-direction.md) |
| [011-team-development](011-team-development/spec.md) | Team | Documentation prepared; independent review pending |
| [012-security-baseline](012-security-baseline/spec.md) | Team | Draft; SEC-01 removed in source, other slices open |
| [013-testing-strategy](013-testing-strategy/spec.md) | Team | Draft; CI runs Deno, Dart, UI-package and docs checks, pgTAP runs locally only |
| [014-ai-response-contracts](014-ai-response-contracts/spec.md) | Dev 2 | Built on dev (strict validator, bounded repair); acceptance pending |
| [015-ai-server-gateway](015-ai-server-gateway/spec.md) | Dev 2 | Built on dev (gateway, quotas, provider order, key-free client); release evidence pending |
| [016-calendar-date-storage](016-calendar-date-storage/spec.md) | Dev 1 | Built on dev (`calendar_dates` migration); acceptance pending |
| [017-kitchen-unit-conversion](017-kitchen-unit-conversion/spec.md) | Dev 1 | Partly built (base-unit conversion, versioned factors); kitchen-measure acceptance pending |
| [018-ingredient-catalog](018-ingredient-catalog/spec.md) | Dev 1 | Built on dev, read-only on the client (tables, reviewed seed, matcher, nutrition reference, allergen groups); household writes pending |
| [019-meal-selection-rules](019-meal-selection-rules/spec.md) | Dev 2 | Built on dev (labels, filters, placement rules, member tastes); allergen-safe plans pending |
| [020-catalog-shopping](020-catalog-shopping/spec.md) | Dev 1 | Draft; identity contract in review |
| [021-home-and-cooking](021-home-and-cooking/spec.md) | Dev 4 | Built on dev (Home, cooking mode, cooked events); acceptance pending |
| [022-simple-pantry](022-simple-pantry/spec.md) | Dev 4 | Built on dev; awaiting independent review |
| [023-optional-nutrition](023-optional-nutrition/spec.md) | Dev 3 | Partly built (reference values, recipe calculation); diary, goals and screens not built |
| [024-store-prices](024-store-prices/spec.md) | Dev 1 | Draft; basket comparison in review |
| [025-receipt-qr-spike](025-receipt-qr-spike/spec.md) | Dev 1 | Draft; resolve recorded questions before dependent implementation |
| [026-cookbook-library](026-cookbook-library/spec.md) | Dev 2 | Built on dev (upload, processing, sourced questions); acceptance pending |
| [027-voice-recipe-agent](027-voice-recipe-agent/spec.md) | Dev 4 | Built on dev (voice recipe drafting); acceptance pending |
| [028-windows-support](028-windows-support/spec.md) | Dev 4 | Built on dev (runner, title bar, MSIX, CI build); real-machine evidence pending |
| [029-private-cycle-hints](029-private-cycle-hints/spec.md) | Dev 3 | Draft; resolve recorded questions before dependent implementation |
| [030-nutritionist-plan-import](030-nutritionist-plan-import/spec.md) | Dev 2 | Draft; resolve recorded questions before dependent implementation |
| [031-external-ui-library](031-external-ui-library/spec.md) | Dev 4 | In progress: local `packages/tavli_ui` package, built from the design canvas; used by Home, Plan, Profile and recipe screens |
| [032-website-downloads](032-website-downloads/spec.md) | Dev 4 | Draft; resolve recorded questions before dependent implementation |
| [033-release-operations](033-release-operations/spec.md) | Dev 3 | Draft; resolve recorded questions before dependent implementation |
| [034-linux-support](034-linux-support/spec.md) | Matija / Dev 3 | In progress: GTK runner, CI build and link registration on dev; device evidence pending |
| [035-fasting-holidays](035-fasting-holidays/spec.md) | Dev 2 | Partly built (church calendar, Home card, questions, fasting plan); Home entry and RAG decided 2026-11-20, open questions Q1–Q7 |

"Built on dev" means the code is merged into `dev` and was found in the source on
2026-11-24. It is not acceptance: a spec is Done only with its tasks, tests, review
and evidence. Specs not listed as built are drafts or in review. Task checkboxes in
each `tasks.md` are unchanged.

## Implementation evidence by spec — 2026-11-24

How each "built" spec is implemented on `dev`, and what is waiting for merge.
Open pull requests are not on `dev`. Task checkboxes in `tasks.md` are unchanged and
mostly unchecked, so they do not reflect this table.

| Spec | Implemented on `dev` | Missing or waiting for merge |
| --- | --- | --- |
| 008 | Migrations for setup, invitations and join, departure, removal, ratings, favorites, allergen selections and member planning sharing; `lib/account/household_*`, `lib/features/account/household_*`, `lib/features/settings/tastes/`, recipe rating section; `planning-inputs`, `household-join`, `household-invite` and `household-photo-cleanup` functions | Allergens are stored but not shown on ingredients or recipes and not applied to plans (T018 to T019); acceptance evidence |
| 009 | `household_realtime_signals` and `solo_household_realtime` migrations, `lib/sync/realtime_sync.dart`, `supabase_sync_signals.dart`, wired in `lib/app/app.dart` | Acceptance evidence |
| 012 | Client no longer reads shared provider keys (SEC-01 removed) | All other slices; key-free artifact proof; rotation of keys from older builds |
| 014 | `lib/ai/ai_response_validator.dart`, `repair_prompt.dart`, bounded repair in `AIRouter` | Contract agreement (T001 to T003); acceptance evidence |
| 015 | `ai-gateway` function with quota (`ai_reserve`), provider order, `gateway_chat_client.dart`, key-free client, AI recipe images | Persisting the quota pause across restarts (T005d); deploy evidence, rollback and rotation record (T006a) |
| 016 | `calendar_dates` migration, `CivilDate` in `lib/domain/plan_calendar.dart` | Acceptance evidence |
| 017 | Base-unit conversion and versioned factors in `lib/domain/food_conversion.dart` (#118, #156) | Kitchen-measure aggregation acceptance |
| 018 | `food_catalog`, `initial_food_catalog_seed`, `food_nutrition_reference`, `food_allergens` migrations; read-only download (`FoodEntity`, `FoodAliasEntity`), `FoodCatalogReader`, `FoodMatcher`, catalog-ready AI names | [#158](https://github.com/anjahubac/tavli/pull/158) (alias cache rebuild on stale schema); household catalog writes; backfill of existing recipe ingredients |
| 019 | `recipe_labels` migration, labels sheet, filters (`recipe_search.dart`), placement rules (`meal_rules.dart`), snack meal types, member tastes in plan requests | Allergen-safe plans; acceptance evidence |
| 021 | `cooked_events` migration, `CookingRepository` (cook, undo, pantry consumption in one transaction), Home, cooking mode and step timers | Acceptance evidence; nutrition intake hook |
| 022 | `lib/data/pantry_repository.dart`, `lib/features/pantry/`, "Prebaci u ostavu", pantry from photo (`pantry_ai.dart`), "Šta da skuvam?" | Independent review |
| 023 | `lib/domain/food_nutrition.dart` and `recipe_nutrition.dart` with attributed reference values | Diary, goals, calorie strip and screens |
| 026 | `cookbooks` migrations, `cookbook-process` and `cookbook-ask` functions, `lib/features/cookbooks/`, `cookbook_repository.dart` | Acceptance evidence; text-only PDF/EPUB (no OCR) |
| 027 | `voice-transcribe` function, `voice_agent.dart`, `lib/features/recipes/voice_*` | Acceptance evidence on each platform |
| 028 | Windows runner, in-window title bar and menu, `scripts/build-windows.ps1`, MSIX config, `windows` CI job | Real-machine evidence; public distribution |
| 031 | `packages/tavli_ui` components, gallery and tests; Home, Plan, Profile and recipe screens use them | [#153](https://github.com/anjahubac/tavli/pull/153) (hide debug galleries); remaining screens |
| 034 | `linux-build` CI job, GTK runner, `scripts/linux-register-links.sh` | Device evidence |
| 035 | `lib/domain/church_calendar.dart`, Home status card, `fasting_questions.dart`, fasting plan draft | "Pratim post" household setting; open questions Q1 to Q7 |

Drafts with a pull request in review: 020 ([#131](https://github.com/anjahubac/tavli/pull/131),
identity contract) and 024 ([#150](https://github.com/anjahubac/tavli/pull/150), basket
comparison and `store-price-import`). Semantic recipe search
([#160](https://github.com/anjahubac/tavli/pull/160)) is also in review.

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

001–035 are allocated. Reserve the next number (currently 036)
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
