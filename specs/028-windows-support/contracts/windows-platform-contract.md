# Contract: Windows platform v1

**Status**: Accepted 2026-11-19 | **Spec**: [028 Windows support](../spec.md)
**Producer / consumers / reviewer**: Dev 4 platform target / account, recipes,
data, sync and CI / Dev 3 independent human review before merge

## Scope and existing behavior

The initial target is Windows 10 or later on x64. ARM64 and older Windows
versions are not claimed. The app keeps its Material UI, responsive breakpoints,
six-digit email OTP authentication, account-scoped drift cache, outbox and
device-only secret storage. No business-data, wire-format, Supabase or drift
schema change is needed.

The baseline has no `windows/` runner and no Windows CI job. Existing widget
tests already treat Windows as a desktop for recipe photo selection, but they do
not prove a native file dialog, DPAPI-backed storage, wake lock or installation.
The current auth flow verifies a code entered in the app; it does not consume an
OS auth callback. Future OAuth/deep-link registration is outside this slice.

## Plugin and OS integration audit

| Boundary | Locked implementation | Windows contract |
| --- | --- | --- |
| Secrets/session | `flutter_secure_storage` 11.2.0, Windows 4.2.2 | Store session and user keys with the Windows implementation; build requires C++ ATL. Platform failures expose only a typed/sanitized category and fail closed. |
| Recipe image | `image_picker` 1.2.4, Windows 0.2.2, `file_selector_windows` 0.9.3+6 | Native file dialog with image filters. No Windows camera control. Cancel returns `null` and performs no AI, file or database write. Bytes are downscaled by the existing post-pick path. |
| Cache | `drift_flutter` 0.3.1, `sqlite3` 3.5.2, `path_provider_windows` 2.3.0 | Keep `tavli.sqlite` in the platform application-documents location. Preserve account scoping, pending outbox and offline restart; no migration. |
| Wake lock | `wakelock_plus` 1.8.2 | Preserve the existing persisted toggle and recipe-scope enable/disable behavior; release on scope disposal and sanitize failure diagnostics. |
| Lifecycle/sync | Existing app listeners | Existing auth restore and sync resume behavior stays intact. This slice adds no shared lifecycle behavior. |
| Packaging | `msix` 3.18.0 (planned dev dependency) | Create an installable MSIX. Test signing is local/tester-only; trusted public signing and distribution are deferred to spec 033. No Store publication is part of this feature. |

Official support evidence was checked on 2026-11-19 against the package pages
and Flutter Windows documentation. Actual behavior remains unverified until the
pinned build and real-machine fixtures pass.

## Interface and outcomes

No public domain or repository interface changes. Platform adapters keep the
existing injectable boundaries:

- `PhotoPicker.pick(camera: false) -> Uint8List?`; `null` means user cancel.
  `camera: true` is never presented on Windows.
- `SecretStorage.read/write/delete`; a platform refusal becomes
  `SecretStorageException` without secret values or raw platform text. Session
  persistence failure prevents sign-in completion and shows
  “Funkcija nije dostupna na ovom uređaju.”
- `ScreenWakeLock.enable/disable`; failures do not crash or expose raw exception
  text. Existing recipe-scope behavior is preserved.

## State transitions

1. **OTP and cache**: signed out -> code sent -> code verified -> session stored
   -> account cache selected. If secure storage refuses the write, remain signed
   out and show the Serbian fallback. Restart offline reads the stored session
   and matching cached account without crossing account or environment scope.
2. **Photo**: open dialog -> cancel returns to the unchanged screen, or select ->
   read/downscale -> existing AI preview. Repeated cancel/select does not create
   a recipe or photo until the existing save action.
3. **Wake lock**: requested off/on is persisted as today. The recipe scope
   enables or disables the platform request and releases it on disposal. Minimize
   and background semantics are unchanged by this Windows slice.
4. **Install**: clean machine installs the MSIX, starts Tavli, and can uninstall
   it. A test certificate is not represented as public signing.

## Compatibility and fixtures

- Security cases follow
  [the 012 security matrix](../../012-security-baseline/contracts/security-test-matrix.md);
  native plugin coverage is J13 in
  [the 013 journey matrix](../../013-testing-strategy/contracts/journey-matrix.md).
- Unit/widget: Windows is desktop; picker cancel/error/repeat; secure-storage
  read/write refusal with sanitized Serbian UI; wake-lock toggle/dispose and
  rejected calls; keyboard, 320/400/1200 widths and 2x text where UI changes.
- Existing offline/replay and account-switch suites remain the deterministic
  cache/outbox evidence. A Windows restart smoke verifies the native path on the
  same synthetic account without inspecting cache contents or tokens.
- CI: clean `windows-latest` x64 release compilation on Flutter 3.50.0. The
  existing Ubuntu job owns analysis and full tests; Windows CI retains no build
  artifact and does not claim native dialog, DPAPI, install or wake-lock proof.
- Manual Windows 10/11: install/start/uninstall, OTP sign-in, offline restart,
  file select/cancel, storage failure, wake-lock toggle/recipe exit,
  resize/scaling, keyboard navigation and native dialogs. Record SHA, OS,
  commands, result, reviewer and remaining limits without personal data.

## Delivery slices

| Slice | Implementer / reviewer | Exact paths | Remaining effort and risk |
| --- | --- | --- | --- |
| T002-T003 target and behavior | Dev 4 / Dev 3 | `windows/`, `pubspec.*`, recipe/account adapters and tests, Windows evidence docs | 1-2 implementation days plus review; medium risk in native secure storage and lifecycle proof |
| T004-T005 CI/package | Dev 4 / Dev 3 | `.github/workflows/check.yml`, packaging config and evidence docs | 0.5-1 implementation day plus first hosted run/review; medium risk in runner/ATL and signing separation |
| T006 hardware/release evidence | Dev 4 / Dev 3 | this spec's evidence and task records | 0.5-1 day plus access to a clean Windows user/machine; public signing remains external |

## Decisions

- Accepted by the product owner on 2026-11-19: Windows 10+ x64, standard public
  repository CI on `windows-latest`, local/tester MSIX installation, no Store
  publishing in this feature, current OTP auth, file-only desktop picker and honest plugin
  fallbacks.
- Independent Dev 3 review and actual CI/hardware evidence remain gates. No
  public distribution, Store reservation or signing credential is implied.
