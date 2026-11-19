# Windows development and packaging

Tavli supports Windows 10 or later on x64. Flutter 3.50.0 is the pinned SDK.
The Windows target is an ordinary Flutter desktop runner; account, sync and AI
boundaries are shared with the other platforms.

## One-time workstation setup

Install Flutter 3.50.0 stable and Visual Studio 2022 or Build Tools 2022 with
the **Desktop development with C++** workload, a Windows 10/11 SDK and C++ ATL.
Enable Windows Developer Mode so Flutter plugins can create symlinks. Verify the
setup before building:

```powershell
flutter doctor -v
flutter pub get
```

The Android warning from `flutter doctor` is unrelated to a Windows-only
workstation. The Visual Studio and Windows checks must be green.

## Build and run

```powershell
flutter build windows --debug
flutter run -d windows
flutter build windows --release
```

The unpackaged release bundle is under
`build/windows/x64/runner/Release/`. Keep the whole directory together; the
executable depends on the adjacent DLLs and `data` directory.

Account-backed use needs the same gitignored configuration as the other
platforms. Pass it with `--dart-define-from-file` as described in `AGENTS.md`.
Never put those values into the runner, MSIX configuration or CI.

## Create and test an installer

The development dependency `msix` creates a locally installable package:

```powershell
dart run msix:create
Add-AppxPackage build\windows\x64\runner\Release\tavli.msix
```

For development, the tool offers to install its self-signed test certificate.
That certificate establishes trust only on the test machine. It is not suitable
for a public download or a release claim. Remove the installed test package with:

```powershell
Get-AppxPackage com.tavli.tavli | Remove-AppxPackage
```

Microsoft Store publication, public code signing and hosted distribution are
deferred to spec 033. The package identity in this repository is for local
sideload testing and can be replaced by an approved release identity later.

## CI and acceptance

The `windows` job in `.github/workflows/check.yml` runs on `windows-latest`,
pins Flutter 3.50.0 and verifies that the x64 release build compiles. The existing
Ubuntu `check` job owns analysis and the full Flutter test suite, so the Windows
job does not duplicate them. CI does not upload a bundle or publish an MSIX.

Before merging Windows changes, record evidence for:

- release compilation and installed-MSIX start/close;
- file selection and cancellation;
- secure-storage denial with sanitized Serbian feedback;
- existing wake-lock toggle, persistence and release on leaving a recipe;
- resize, scaling and keyboard navigation;
- OTP sign-in, offline restart and account-scoped cache/outbox behavior; and
- uninstall without deleting server data.

Automated tests cover the picker, secure-storage and lifecycle fallbacks. OTP,
offline restart, native dialogs and clean-machine install/uninstall still need
manual evidence with synthetic/local data; CI compilation does not prove them.
