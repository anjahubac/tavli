# Capstone evidence map

Where to find the evidence for each capstone area (CAP-01 to CAP-08). It points
to files in this repository and says what is **not** proven yet. Status is
written as of 2026-11-24 on `dev`; check the linked file before relying on it.
A link is source evidence, not a claim that the behavior was run live.

| Area | Evidence in the repository | Not proven yet |
| --- | --- | --- |
| CAP-01 Spec and plan | [Product plan](../product-plan.md), [roadmap](../roadmap.md), [spec index](../../specs/README.md), [architecture](../architecture.md) | |
| CAP-02 Application | Photo to review to plan to list in the app: `lib/features/recipes/`, `lib/features/planning/`, `lib/features/shopping/`. Server step: [`supabase/functions/ai-gateway/`](../../supabase/functions/ai-gateway/) and its [contract](../../specs/015-ai-server-gateway/contracts/ai-gateway-contract.md); client strict validation: `lib/ai/ai_response_validator.dart` | Run through the gateway with sign-in recorded on a local stack with a synthetic user: [gateway-flow.md](../../evals/capstone/gateway-flow.md); not run against the hosted project |
| CAP-03 Sources | Cookbook answers show their book and page: `lib/features/cookbooks/cookbook_ask_screen.dart`, [spec 026](../../specs/026-cookbook-library/spec.md); fasting answers show their source: `lib/features/fasting/fasting_questions.dart` | Unconfirmed items and the source of a saved recipe in one screen: check against the canvas |
| CAP-04 Workflow | Approved recipe to shopping totals: `lib/data/shopping_totals.dart`, case EV-04 in [`test/evals/capstone_eval_test.dart`](../../test/evals/capstone_eval_test.dart), [flow map](../flows.md) | Confirmed recipe from the live flow reaches the totals (GW-01 in [gateway-flow.md](../../evals/capstone/gateway-flow.md)); a manual "Brašno" and the recipe's "pšenično brašno" are not summed because the names differ |
| CAP-05 Evaluation | [Cases](../../evals/capstone/cases.jsonl), [README](../../evals/capstone/README.md), [results](../../evals/capstone/results.md), before/after: [ingredient names](../../evals/capstone/trace-ingredient-names.md), [EV-12 repair](../../evals/capstone/traces/ev12-repair-before-after.jsonl) | Live cases EV-01 to EV-03, EV-06, EV-07, EV-09, EV-10 were recorded with a personal key through `RecipeAI`, not through the gateway; rerun them through the gateway and update `results.md` with the commit |
| CAP-06 Security | [Security baseline](../development/security.md) (controls, gateway tests, known gaps), [spec 012](../../specs/012-security-baseline/spec.md), pgTAP tests in [`supabase/tests/`](../../supabase/tests/), macOS release build searched for provider keys with a positive control: [artifact-check.md](artifact-check.md) | Open items are listed as known limits there: arbitrary client prompts, CI gate before deploy (SEC-08), database encryption (SEC-04), hosted OTP settings (SEC-05) |
| CAP-07 Delivery | [README](../../README.md), [quality gates](../development/quality-gates.md), CI in `.github/workflows/check.yml`, README steps run from a clean clone of `dev` on macOS: [artifact-check.md](artifact-check.md) | A tag on the submitted commit; one verified demo configuration with `supabase start` (not run in the clean-clone check); builds for other platforms |
| CAP-08 Individual | Each member's own section below | Every section is filled by its author |

## Individual contributions

Each member adds: the decision they own, how they verified it (command, test or
run), whose work they reviewed, and how it fits the main flow, with links to
pull requests. Do not write a claim here that you cannot show.

| Member | Area | Decision and how it was verified | Review of a colleague | Link to the main flow |
| --- | --- | --- | --- | --- |
| Uroš | Catalog, shopping, search, evaluation | Decision: measure a prompt change on fixed inputs instead of judging it by reading: ingredient-name rules against the `dev` prompt on 30 dishes, two runs each ([trace](../../evals/capstone/trace-ingredient-names.md), PR #117), and the photo prompt before and after on an unreadable card through the gateway ([gateway-flow.md](../../evals/capstone/gateway-flow.md), PR #182). Verified with `flutter test test/evals` (deterministic cases) and the recorded live traces; limits are written next to each result. | PRs #102 (catalog-ready ingredient names), #46 (strict AI response validation), #94, #95 and #96 (household logic) | Photo or dish name gives a recipe (`lib/ai/`), ingredients resolve through the alias matcher (#90) and unit conversion (#118, #156), and a confirmed recipe reaches the shopping totals (#112, #113); GW-01 in [gateway-flow.md](../../evals/capstone/gateway-flow.md) records that path signed in through the gateway |
| Matija | RLS and account | | | |
| Aleksa | AI gateway | | | |
| Anja | Schema, pantry, CI | | | |
