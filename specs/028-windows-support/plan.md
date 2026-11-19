# Implementation plan: Windows application and release validation

**Status**: implementation approved; T001 contract accepted on 2026-11-19.
**Spec**: [requirements](spec.md) | **Lead/review**: Dev 4 / Dev 3
**Baseline**: dev 207c94c; every implementing branch starts from then-current origin/dev.

## Existing boundaries and proposed files

- `windows/ (new target)`
- `pubspec.yaml`
- `lib/features/recipes/photo_picker.dart`
- `lib/features/recipes/keep_screen_on.dart`
- `lib/ai/key_store.dart`
- `.github/workflows/`
- `specs/028-windows-support/contracts/windows-platform-contract.md`

Items marked new/proposed/external do not exist at baseline. Verify exact existing
files and consumers before editing; new files remain in current feature/domain/
data/AI/account/sync layers. Shared providers and schema versions are coordinated.

## Contract and data plan

New target must preserve secure session/key storage, account/environment isolation and file/outbox semantics. Windows is not currently supported merely because Flutter supports it.

The target adds no business-data or wire-format change, drift schema change,
Supabase change or migration. `msix` is the only planned dependency addition,
as a development-only packaging tool needed to create the installable Windows
artifact required by FR-001. Runtime plugin versions remain those already locked.

Producer dependencies: [012](../012-security-baseline/spec.md), [013](../013-testing-strategy/spec.md)

Use [shared boundaries](../011-team-development/contracts/shared-boundaries.md)
and the [contract template](../../.specify/templates/contract-template.md).
Before implementation, record typed fields, validation, identity/units/CivilDate,
error/retry/undo, ownership, compatibility and producer/consumer fixtures. If data
changes, add data-model.md with current→target columns and a reviewed migration;
allocate drift version only after preceding schema merges. New SQL is additive
where possible, with RLS/grants and local two-account tests. Applied SQL is immutable.
If no schema change is needed, explicitly record that decision in the slice PR.

## Delivery slices

1. Resolve only blocking decisions; map each source requirement to existing code,
   identify work already present and record remaining effort. Never redo completed
   behavior simply because a source ticket is unassessed.
2. Merge the agreed contract/fixtures first; no consumer branch stacks on an
   unmerged producer. Independent research/tests may proceed in developers' existing
   checkouts, with one active writer per checkout; no automatic extra worktrees.
3. Implement one source task vertically through affected layers with test-first
   logic/parsing and ownership review. Keep phase boundaries in tasks.md.
4. Integrate consumers after producer merge, preserving offline/replay and previous
   UI/quantity behavior. Run relevant 012/013 gates and update real evidence.

## Accepted Windows delivery decisions

- **Target**: Windows 10+ x64; Flutter-generated Windows runner from the pinned
  3.50.0 SDK, branded as Tavli. ARM64 is not claimed by this slice.
- **CI**: standard GitHub-hosted `windows-latest` for this public repository,
  Flutter 3.50.0, dependency restore and a release Windows compilation. The
  existing Ubuntu job owns analysis and the full Flutter test suite. Windows CI
  does not retain or publish build output and is not native-dialog or real-device
  evidence.
- **Packaging**: MSIX for install/uninstall testing. Local test signing is not a
  public trust claim. Trusted public signing and distribution belong to spec
  033; no Store work or publication is part of this feature.
- **Authentication**: preserve the current six-digit email OTP flow. There is no
  native callback registration to add until a future OAuth provider is accepted.
- **Fallbacks**: file selection only (no desktop camera), cancel without error,
  fail-closed secure storage with sanitized Serbian feedback, wake-lock release
  on inactive/background/dispose, and the existing drift cache path.
- **Manual hardware**: Windows install/start, OTP sign-in, restart offline,
  picker select/cancel, storage denial, wake-lock lifecycle, resize/scaling,
  keyboard and uninstall are recorded against the tested SHA.

## Constitution check (3.0.0)

| Gate | Required response before implementation |
| --- | --- |
| I | English docs; exact Serbian Latin UI/copy for changed screens |
| II | Preserve outbox/account scope; explicit personal/device/reference classification |
| III | Any AI through AIRouter and validated task contract; N/A documented if none |
| IV | No real secrets/logged private content; apply 012 trust-boundary controls |
| V | Test-first logic/parsing; local SQL/Edge tests when backend changes |
| VI | Phone/wide/text/motion/keyboard proof for UI; N/A for technical-only slice |
| VII | Reviewable task slices; generated files via generator only |
| VIII | This canonical spec, owned dev-based branch/task IDs, no stacking |
| IX | Existing paths/interfaces; justify dependencies and migration decisions |
| X | Named human reviewer, producer/consumer contract and schema coordinator |

These are design obligations, not executed pass results. Any violation blocks Ready
until resolved under governance. No dependency is added by this documentation;
implementer records each proposed package/service with a reason before adoption.

## Verification, rollout and risks

Use [testing 013](../013-testing-strategy/spec.md), its journey matrix, and
[security 012](../012-security-baseline/spec.md). Tests must prove the scenarios
in spec.md and source task outcomes using synthetic data/fake AI. Default Flutter
tests do not contact a network; explicit guarded integration uses local services.
No speculative hosted deployment or publication. Record old-client/snapshot
compatibility, pending-outbox migration, failure/undo and forward recovery for
state changes. No destructive reset as a migration. Platform/source/legal/retention
limits from open questions remain release gates. UI checks use current theme/
motion components; do not redesign screens or extract a package incidentally.
