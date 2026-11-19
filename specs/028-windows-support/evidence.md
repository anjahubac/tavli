# Windows validation evidence

**Branch**: `028-windows-support`

**Machine**: Windows 11 25H2, x64

**Date**: 2026-11-19

This record distinguishes local implementation evidence from hosted CI,
independent review and wider release evidence. It contains no credentials or
personal test data.

## Completed locally

| Evidence | Result |
| --- | --- |
| Flutter toolchain | Flutter 3.50.0 stable and Dart 3.14.0 installed; `flutter doctor -v` reports green Windows and Visual Studio checks. The unrelated Android SDK is not installed on this Windows-only workstation. |
| Native prerequisites | Visual Studio Build Tools 2022 17.14.45, Desktop C++ workload, C++ ATL and Windows SDK 10.0.26100.0 installed; Windows Developer Mode enabled for plugin symlinks. |
| Debug compilation | `flutter build windows --debug` succeeded and produced `build/windows/x64/runner/Debug/tavli.exe`. |
| Release/package compilation | `dart run msix:create` completed a release build and produced `build/windows/x64/runner/Release/tavli.msix`. The package used the tool's self-signed development certificate; this is not public trust evidence. |
| Install/start | `Add-AppxPackage` installed `com.tavli.tavli_1.0.0.0_x64__fxkeb4dgdm144`. Launch through `com.tavli.tavli_fxkeb4dgdm144!tavli` opened a responsive window titled `Tavli`, which then closed normally. |
| Automated fallback coverage | Test-first runs reproduced missing typed secure-storage handling and background wake-lock release before implementation. The final commit gate passed `flutter analyze` and all 642 Flutter tests, including Windows picker routing, picker cancellation, sanitized storage failures and lifecycle transitions. |
| Native target commit | `b082f68` (`feat(windows): add desktop target and installer`). |
| CI configuration | `735182e` introduced the `windows-latest` release compilation; the current workflow keeps only dependency restore and compilation, with no duplicate tests or uploaded artifact. |

## Evidence still required before delivery Done

- A green hosted GitHub Actions Windows compilation for the exact reviewed SHA.
- Independent human review and merge into `dev`.
- OTP sign-in against synthetic/local or approved development configuration,
  followed by offline restart and account-scoped cache/outbox verification.
- Real native file-dialog select/cancel, native secure-storage denial, wake-lock
  observation, resize/scaling, keyboard navigation and uninstall verification.
- A clean Windows 10/11 x64 machine install, separate from the development
  workstation whose test certificate is already trusted.

Windows ARM64, Microsoft Store publication, trusted public signing and hosted
distribution remain outside this slice and belong to release spec 033.
