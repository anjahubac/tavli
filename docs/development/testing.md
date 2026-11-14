# Testing Tavli

[Spec 013](../../specs/013-testing-strategy/spec.md) is the canonical testing
implementation plan; [012](../../specs/012-security-baseline/spec.md) defines
security-specific controls. [Quality gates](quality-gates.md) define when checks
run. Each feature owner writes behavior tests; Dev 3 coordinates infrastructure,
Dev 4 device/UX harnesses, and another human reviews the evidence.

## Select the cheapest test that proves the boundary

| Change | Primary evidence | Additional evidence |
| --- | --- | --- |
| Quantity/date/parser/router logic | Deterministic test-first unit cases | Repository/widget consumer regression |
| Repository/outbox/schema | In-memory or temporary DB transaction/upgrade tests | Local SQL and two-client sync when boundary changes |
| Screen/state | Widget actions, semantics, text/motion/layout and failures | A few device journeys, manual native/UX checks |
| RLS/storage/RPC/function | Local two-account negative and positive tests | Same-SHA security deployment gate |
| Native/plugin/release | Actual supported device/build proof | Fakes only verify app-side decisions |
| Documentation/scripts | Link/registry checks and meaningful script fixtures | No artificial runtime tests for prose |

Reuse test/helpers; clean up even after failed assertions. Inject time and IDs,
use bounded pumping for transient animations and no real sleeps. Default unit/
widget tests have no network, keys or production data. Explicit local-backend
integration is isolated and guarded; AI stays fake in every automated lane.
A fake cannot prove RLS, nor can a widget test prove a native permission dialog.

Current baseline: 64 Dart test files and 7 SQL suites, no integration_test harness.
See the [quickstart](../../specs/013-testing-strategy/quickstart.md) for actual
commands and [journey matrix](../../specs/013-testing-strategy/contracts/journey-matrix.md)
for required outcomes. Record failures/limits, don't infer correctness from counts.

Coverage supports review; retain the existing 80% domain/AI target but establish
measured baseline and exclusions before introducing an enforced CI threshold.
Test critical boundaries regardless of percentage. Golden tests are selective,
not a blanket screenshot of every screen. Flaky tests get an owner and a fix;
no skip/delete or automatic retries to manufacture green. Report the original
failure even when an investigative rerun passes.

Future features inherit their relevant matrix rows and add concrete acceptance
fixtures. Record command, SHA, platform, result and reviewer. Store only redacted
bounded artifacts. No implemented feature is Done without its required evidence.
