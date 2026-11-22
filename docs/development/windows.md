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

Use the build script for local Windows builds that need to open `tavli://`
links, including email confirmation. The script builds Tavli and registers
the resulting executable for the current Windows user. Close any running
copy of that build and run these commands from the repository root:

```powershell
.\scripts\build-windows.ps1
.\build\windows\x64\runner\Debug\tavli.exe
```

The defaults are `-Mode Debug` and `-DefinesFile .\secrets.json`. Choose the
build mode and configuration file independently:

```powershell
# Build and run Release with secrets.json
.\scripts\build-windows.ps1 -Mode Release
.\build\windows\x64\runner\Release\tavli.exe

# Build and run Debug with the dev configuration
.\scripts\build-windows.ps1 -DefinesFile .\secrets.dev.json
.\build\windows\x64\runner\Debug\tavli.exe
```

Open Tavli from the executable the script registered so the confirmation link
returns to the same instance. The latest successful run of the script selects
the executable. Run the script again when switching between Debug and Release
or using a different checkout. Keep each build directory together because the
executable depends on its adjacent DLLs and `data` directory.

For hot reload, register the Debug executable with the script first, then run
Flutter from the same checkout. Direct Flutter builds and runs rely on the
existing Windows handler for links.

```powershell
flutter run -d windows --dart-define-from-file=secrets.json
```

Keep the defines file gitignored. Flutter can embed values used by the app
into either build, so keep build bundles private when they contain credentials.
The registry stores the executable path and a placeholder for the incoming URI.

## Create and test an installer

For an installed build, Windows registers `tavli://` from the MSIX manifest
at install time. Build a Release bundle with your chosen defines file, then
package that bundle with `msix`:

```powershell
flutter build windows --release --dart-define-from-file=secrets.json
dart run msix:create --build-windows false
Add-AppxPackage build\windows\x64\runner\Release\tavli.msix
```

Start Tavli from the Windows Start menu and use the email link from that
session. If a previous local script registration selects an unpackaged build,
remove `HKCU\Software\Classes\tavli` if it still points to that local build so
the link opens the installed package.

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
