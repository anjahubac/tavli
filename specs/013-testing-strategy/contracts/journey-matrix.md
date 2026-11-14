# Critical test journeys and owners

Baseline evidence means existing files to extend, not a claim every case passes.
Tier: U=unit/domain, R=repository/sync, W=widget, L=local backend, D=device,
M=manual UX/native. A small D journey complements detailed U/R/W fixtures.

| ID | Behavior and failure assertion | Tier / existing evidence | Owner / reviewer | Delivery gate |
| --- | --- | --- | --- | --- |
| J01 | Sign-in, wrong/expired/reused code, restart, sign-out retention; no cross-account access | W/R: test/account, test/features/account; L/D additions | Dev 3 / Dev 4 | Current auth; real provider never used in default suite |
| J02 | Photo/name/manual recipe → preview/save; AI bad JSON/fallback/cancel leaves no partial recipe | U/W: test/ai, test/features/recipes; D addition | Dev 2 / Dev 1 | Current recipe workflow |
| J03 | Week/month draft → approve; old draft, locked meal, servings, original snapshot preserved | U/R/W: plan_calendar, meal_plan_ai, meal_plan_repository and planning tests | Dev 2 / Dev 1 | Current planning + future snack/rule extensions |
| J04 | Mark two of three ingredients available, add one; unmark another, add only that new one | U/R/W: shopping_demand, shopping_repository, recipe_shopping tests | Dev 1 / Dev 4 | Current standalone shopping |
| J05 | Two recipes share food; change/remove one source without removing other's need or bought/manual rows | U/R: shopping_source, supply_allocation, shopping_repository | Dev 1 / Dev 2 | Current quantities + catalog migration |
| J06 | Month spans six weeks; year/month/DST boundaries preserve CivilDate and weekly list identity | U/R/W: plan_calendar, shopping_sync and planning calendar tests | Dev 1 / Dev 2 | Current dates + spec 016 |
| J07 | Explicit bought transfer is idempotent; purchase and pantry receipt supply counted once | R: pantry_repository, shopping_repository; W/D additions | Dev 4 / Dev 1 | Current repository; pantry UI spec 022 |
| J08 | Cook/undo consumes/restores known stock once, unknown stock persists, other members' intake unaffected | U/R/W additions | Dev 4 / Dev 1+3 | Specs 021/022/023; not current complete feature |
| J09 | Offline edit → close/reopen → reconnect; rejected/duplicate/out-of-order events do not lose pending writes | R: sync tests; L two clients and D restart additions | Dev 1 / Dev 3 | Current sync; realtime spec 009 |
| J10 | Fresh schema and supported upgrades preserve IDs, source allocations, quantities, pending outbox | R: migration_test and v3/v4 helpers | Dev 1 / Dev 3 | Every schema PR |
| J11 | Wrong household/parent/object/RPC access denied while valid member succeeds; deletion retry safe | L: supabase/tests; local Edge additions; 012 matrix | Dev 3 / Dev 1 | Every backend/auth/privacy change |
| J12 | Phone/wide, themes, 2× text, reduced motion, keyboard and semantics remain usable; safe areas never hide CTA | W: app/features suites; M first-use study | Dev 4 / affected owner | Every UI change + release |
| J13 | Photo/key/session/wake-lock/plugin lifecycle works; denied permission returns actionable UI | D/M: existing fake tests are only lower-tier evidence | Dev 4 / Dev 3 | Android/iOS/macOS; Windows after 028 |
| J14 | Catalog/units mapping preserves original text; unknown values stay unknown; nutrition uses sources/coverage | U/R/W additions | Dev 1 / Dev 2+3 | Specs 017/018/020/023 |
| J15 | Invite/remove/transfer reconnect, private diary/favorites boundaries, realtime resubscription | U/R/W/L additions | Dev 3 / Dev 1 | Specs 008/009/023 |
| J16 | Gateway limits/auth; RAG isolation/deletion; voice only drafts; import exact grams/locked meals; cycle stays local | 012 matrix + feature-specific tests | Dev 2/3/4 / consumer | Specs 015/026/027/029/030 |

For J07 example: demand 300 g, stock 100 g, buy 200 g, transfer: coverage remains
300 g; increasing demand to 400 g creates only 100 g new need. Test duplicate
transfer and replay. For J08 test operation identity and undo twice; do not
subtract pantry supply twice via both purchase and cooking paths.

A CI result records SHA, command, fixture/seed, platform, duration, outcome and
artifact location. A manual result records build/device, steps and actual result.
Do not mark M/L/D covered merely because a W test passes. First-use evaluation
retains the 010 target: five participants, at least four complete core journeys
without coaching; report issues and retest, not just a polished screenshot.
