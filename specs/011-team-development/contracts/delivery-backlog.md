# Delivery backlog — source task traceability

Status: imported inventory, not a completion report. English titles translate the
87 source CSV rows in their original order. Source row numbers and SHA-256 live
in [task-register.json](../../../docs/development/task-register.json). All tasks
start as **not assessed** here; Trello assignments are preserved, but runtime
completion/remaining effort must be verified per feature. No source ticket is
automatically marked Done. Phase numbers are product phases, not spec numbers.

[Product plan](../../../docs/product-plan.md) defines preparation gates. TEAM-SETUP
is workflow/infrastructure; WEBSITE is external release preparation. Other keys
map to that plan's feature register. Each task needs a focused spec requirement,
reviewer, accepted contract, implementation/test/integration effort range and
merged evidence before Ready/Done. Source prose requiring human/source/legal
review remains a gate, not permission for an agent to approve it.

The [source-to-spec mapping](../../../docs/development/source-task-map.md) links
every row below to its requirement and test/implementation tasks. This does not
change source status or imply the new specs are implemented.

## Dev 1 — umilutinovic25 (20 tasks)

| Task | Phase | English task title | Feature key |
| --- | --- | --- | --- |
| D1-001 | 1 | Agree the ingredient model | CATALOG |
| D1-002 | 1 | Migrate calendar-day columns to dates without time zones | DATES |
| D1-003 | 1 | Aggregate kitchen measures in shopping | UNITS |
| D1-004 | 1 | Split shopping code by responsibility | SHOPPING-FOODS |
| D1-005 | 2 | Create ingredient catalog tables | CATALOG |
| D1-006 | 2 | Review and seed 300–400 ingredients | CATALOG |
| D1-007 | 2 | Resolve ingredient names through the shared matcher | CATALOG |
| D1-008 | 2 | Map existing recipe ingredients to the catalog | CATALOG |
| D1-009 | 2 | Provide unresolved-ingredient review UI | CATALOG |
| D1-010 | 2 | Support ingredient-specific units and conversions | CATALOG |
| D1-011 | 2 | Add attributed nutrition reference values | NUTRITION |
| D1-012 | 3 | Aggregate shopping by ingredient identity | SHOPPING-FOODS |
| D1-013 | 3 | Add manual shopping items from the catalog | SHOPPING-FOODS |
| D1-014 | 3 | Account for pantry stock in shopping | SHOPPING-FOODS |
| D1-015 | 3 | Calculate calories and macros per recipe portion | NUTRITION |
| D1-016 | 3 | Support meals without preparation steps | NUTRITION |
| D1-017 | 4 | Import store price lists | PRICES |
| D1-018 | 4 | Compare basket prices by store | PRICES |
| D1-019 | 4 | Spike: inspect receipt QR data | RECEIPT-QR |
| D1-020 | 6 | Map imported meal-plan items to ingredients | PLAN-IMPORT |

## Dev 2 — Ceviz (ceviz2) (21 tasks)

| Task | Phase | English task title | Feature key |
| --- | --- | --- | --- |
| D2-001 | 1 | Agree recipe and meal-plan AI contracts | AI-SCHEMA |
| D2-002 | 1 | Validate AI responses strictly | AI-SCHEMA |
| D2-003 | 1 | Spike: send an image request through the gateway | AI-GATEWAY |
| D2-004 | 1 | Move built-in AI credentials behind the server | AI-GATEWAY |
| D2-005 | 1 | Annotate recipes with meal suitability and dish type | MEAL-RULES |
| D2-006 | 1 | Represent daily meals as a list including snacks | MEAL-RULES |
| D2-007 | 1 | Validate meal placement rules | MEAL-RULES |
| D2-008 | 2 | Generate catalog-ready ingredient data | CATALOG |
| D2-009 | 2 | Include authorized tastes and preferences in plan requests | MEAL-RULES |
| D2-010 | 2 | Repair invalid AI responses with bounded retries | AI-SCHEMA |
| D2-011 | 3 | Enforce allergen restrictions in plans | MEAL-RULES |
| D2-012 | 3 | Prefer favorite recipes in plans | MEAL-RULES |
| D2-013 | 3 | Select saved recipes locally before generating new ones | MEAL-RULES |
| D2-014 | 3 | Display calculated calories in plans | NUTRITION |
| D2-015 | 4 | Upload cookbook files | COOKBOOKS |
| D2-016 | 4 | Process cookbook files for retrieval | COOKBOOKS |
| D2-017 | 4 | Answer cookbook questions with book/page provenance | COOKBOOKS |
| D2-018 | 4 | Save a cookbook result through recipe review | COOKBOOKS |
| D2-019 | 5 | Add approved cycle-related dietary hints | CYCLE |
| D2-020 | 6 | Import and review a plan from image or text | PLAN-IMPORT |
| D2-021 | 6 | Import PDF plans with alternatives and weekly repetition | PLAN-IMPORT |

## Dev 3 — Matija (matijaradulovic077) (20 tasks)

| Task | Phase | English task title | Feature key |
| --- | --- | --- | --- |
| D3-001 | 1 | Agree the member-input contract for planning | HOUSEHOLD |
| D3-002 | 1 | Complete sign-in refinements | HOUSEHOLD |
| D3-003 | 1 | Configure GitHub collaboration safeguards | TEAM-SETUP |
| D3-004 | 1 | Provide taste and preference settings | HOUSEHOLD |
| D3-005 | 2 | Create invitation data and access rules | HOUSEHOLD |
| D3-006 | 2 | Provide household invitation UI | HOUSEHOLD |
| D3-007 | 2 | Join a household with confirmation | HOUSEHOLD |
| D3-008 | 2 | Manage household members and roles | HOUSEHOLD |
| D3-009 | 3 | Choose structured allergens per member | HOUSEHOLD |
| D3-010 | 3 | Display allergens on ingredients and recipes | HOUSEHOLD |
| D3-011 | 3 | Store favorites per member | HOUSEHOLD |
| D3-012 | 3 | Signal household changes in realtime | REALTIME |
| D3-013 | 4 | Store private intake diary and targets | NUTRITION |
| D3-014 | 4 | Record intake after cooked and ate confirmations | NUTRITION |
| D3-015 | 4 | Provide the nutrition diary screen | NUTRITION |
| D3-016 | 4 | Support three optional nutrition-target modes | NUTRITION |
| D3-017 | 4 | Provide the calorie strip and source-method note | NUTRITION |
| D3-018 | 4 | Rate recipes | HOUSEHOLD |
| D3-019 | 5 | Store cycle consent and dates securely on device | CYCLE |
| D3-020 | 6 | Connect imported plans to diary and allergen checks | PLAN-IMPORT |

## Dev 4 — Anja (anja129) (26 tasks)

| Task | Phase | English task title | Feature key |
| --- | --- | --- | --- |
| D4-001 | 1 | Integrate open changes safely | TEAM-SETUP |
| D4-002 | 1 | Standardize components in the current repository | EVERYDAY-UX |
| D4-003 | 1 | Introduce five-tab navigation with central Home | EVERYDAY-UX |
| D4-004 | 1 | Fix the shopping-mode switch regression | SHOPPING-FOODS |
| D4-005 | 1 | Use camera/gallery on phone and file selection on desktop | EVERYDAY-UX |
| D4-006 | 1 | Provide the monthly plan view | EVERYDAY-UX |
| D4-007 | 1 | Keep mobile primary actions above navigation | EVERYDAY-UX |
| D4-008 | 1 | Align meal cards and show accessible cooked status | EVERYDAY-UX |
| D4-009 | 2 | Provide the shared cooked/undo operation | EVERYDAY-UX |
| D4-010 | 2 | Show today's meals on Home | EVERYDAY-UX |
| D4-011 | 2 | Show one prioritized notice on Home | EVERYDAY-UX |
| D4-012 | 2 | Provide a readable cooking mode | EVERYDAY-UX |
| D4-013 | 2 | Add a recipe to a selected plan slot | EVERYDAY-UX |
| D4-014 | 3 | List and add pantry ingredients | PANTRY |
| D4-015 | 3 | Remove pantry ingredients with undo | PANTRY |
| D4-016 | 3 | Receive checked purchases into the pantry | PANTRY |
| D4-017 | 3 | Consume and edit pantry quantities with reversal | PANTRY |
| D4-018 | 4 | Capture voice and transcribe speech | VOICE |
| D4-019 | 4 | Apply allowlisted voice draft commands and speak responses | VOICE |
| D4-020 | 4 | Add and validate the Windows target | WINDOWS |
| D4-021 | 4 | Build Windows in CI | WINDOWS |
| D4-022 | 4 | Integrate the optional calorie strip on Home | NUTRITION |
| D4-023 | 4 | Use real store links and app screenshots on the website | WEBSITE |
| D4-024 | 4 | Build the external UI package only after team agreement | UI-PACKAGE |
| D4-025 | 5 | Show a private local cycle indicator in the calendar | CYCLE |
| D4-026 | 6 | Capture and crop a meal-plan image for import | PLAN-IMPORT |
