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

To test email confirmation links with a local Windows build, close any
running copy of that build and run from the repository root:

```powershell
.\scripts\build-windows.ps1
.\scripts\build-windows.ps1 -Mode Release
.\scripts\build-windows.ps1 -DefinesFile .\secrets.dev.json
```

The defaults are `-Mode Debug` and `-DefinesFile .\secrets.json`. Both
`Release` and `Debug` use the selected environment file independently of mode.
Flutter can embed values used by the app into either build. Keep both build
bundles private when they contain credentials. The registry stores only the
executable path and a placeholder for the incoming URI.

After a successful build the script registers `tavli://` for the current Windows
user and points it at the executable for the chosen mode. For the default
build, launch `build\windows\x64\runner\Debug\tavli.exe` to test sign-up in
that instance. Re-run the script if the checkout
moves or to point the protocol at a different checkout. To remove the local
registration, remove `HKCU\Software\Classes\tavli` if it still points to that
build.

## Create and test an installer

The development dependency `msix` creates a locally installable package:

```powershell
dart run msix:create
Add-AppxPackage build\windows\x64\runner\Release\tavli.msix
```

Installing the MSIX registers `tavli://` through the package manifest. For a
local sign-up test, build the Release bundle with your local defines file and
then package the existing bundle:

```powershell
flutter build windows --release --dart-define-from-file=secrets.json
dart run msix:create --build-windows false
Add-AppxPackage build\windows\x64\runner\Release\tavli.msix
```

Start Tavli from the Windows Start menu and use the email link from that
session. If a previous local script registration selects an unpackaged build,
remove that per-user registration before testing the installed package.

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
