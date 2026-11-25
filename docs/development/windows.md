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
Get-AppxPackage AnjaHubac.TavliPlanerobroka | Remove-AppxPackage
```

Packages built before the Store identity used `com.tavli.tavli`; remove an
old test install with `Get-AppxPackage com.tavli.tavli | Remove-AppxPackage`.
The sideload package and the Store package share the Store identity, so remove
the test package before installing Tavli from the Store on the same machine.

## Microsoft Store package

Public Windows distribution goes through the Microsoft Store. An unsigned MSIX
cannot be installed outside the Store, and the Store re-signs the package with
its own certificate after certification, so the repository holds no signing
material for Windows.

### Package identity

`msix_config` in `pubspec.yaml` carries the values from Partner Center →
Apps and games → Tavli → Product management → Product identity:

| `msix_config` key | Partner Center field |
|---|---|
| `identity_name` | `Package/Identity/Name` |
| `publisher` | `Package/Identity/Publisher` |
| `publisher_display_name` | `Package/Properties/PublisherDisplayName` |

These are public identity values, not secrets. `display_name` must match the
name reserved for this app in Partner Center exactly, including the en dash:
`Tavli – Planer obroka`. Windows shows it in Start and in app settings. `capabilities` declares `internetClient` (Supabase and
the AI gateway) and `microphone` (voice recipe drafting, spec 027, through the
`record` plugin). The `msix` tool always adds `runFullTrust`. `languages` is
`sr-latn`, so the Store listing is Serbian (Latin).

`store` is deliberately not set in `pubspec.yaml`. In `msix` 3.18.0 a
`store: true` value cannot be switched off per command, and it would make the
sideload command above produce an unsigned package. Pass `--store` only when
building the Store submission.

### Versioning

`msix_version` is the `major.minor.patch` of `version` in `pubspec.yaml`
followed by `.0` (for example `1.0.0+1` becomes `1.0.0.0`). The Store reserves
the fourth number and rejects a package where it is not 0. Every new submission
needs a higher `msix_version` than the last published one, so bump `version`
and `msix_version` together.

### Build the submission

Run on the Windows workstation from the repository root, on the reviewed commit
that is being released, with the production configuration:

```powershell
flutter pub get
flutter build windows --release --dart-define-from-file=secrets.prod.json
dart run msix:create --store --build-windows false
```

The result is `build\windows\x64\runner\Release\tavli.msix`, unsigned.
It cannot be installed locally; test the same build with the sideload package
first. Record the commit SHA and the package's SHA-256
(`Get-FileHash build\windows\x64\runner\Release\tavli.msix`) as release
evidence (spec 033 FR-106). Upload the `.msix` in Partner Center → Packages.

### Build the submission in CI

Without a Windows workstation, run the `windows-store` workflow
(`.github/workflows/windows-store.yml`): GitHub → Actions → windows-store →
Run workflow, on `main`. It runs only from `main`, waits for approval in the
`production` environment, builds the Release bundle and the unsigned Store
MSIX on `windows-latest`, and publishes nothing. The run summary records the
commit SHA, `msix_version` and SHA-256; the artifact
`tavli-store-<msix_version>-<sha>` contains `tavli.msix` and its checksum file
and is kept for 30 days. Download it and upload `tavli.msix` in Partner Center.

The workflow reads these `production` environment variables, the same values
as `secrets.prod.json`:

| Variable | Value |
|---|---|
| `SUPABASE_URL` | production project URL (shared with `deploy-web`) |
| `SUPABASE_ANON_KEY` | production anon key (shared with `deploy-web`) |
| `AUTH_CONFIRM_PAGE_URL` | the hosted confirmation page, `site/potvrda/`, with the trailing slash; it must be listed in the production Supabase redirect URLs |

The workflow fails before building if any of them is empty. A workflow is
dispatchable only after it reaches the default branch, so the first run is
possible after the next `dev` → `main` release.

### Partner Center submission checklist

- **Pricing and availability:** Free; choose markets; no in-app purchases.
- **Properties:** category Food & dining; declare that the app accesses the
  internet and uses the microphone; privacy policy URL.
- **Privacy policy:** required, because Tavli has accounts and stores personal
  data (recipes, plans, email). The website (`site/`) has no privacy policy
  page yet; publish one before submitting and use its URL here.
- **Age ratings:** complete the IARC questionnaire (no violence, no user-to-user
  public content; household sharing is private).
- **Store listing (Serbian Latin):** description, short description, feature
  list and at least one screenshot of 1366×768 or larger; add the app icon
  where Partner Center asks for logos.
- **Notes for certification:** explain `runFullTrust`, for example: "Tavli is a
  Flutter desktop app; Flutter's Windows runner is a Win32 application, which
  requires the runFullTrust capability. The app does not install services,
  drivers or start-up tasks." Add sign-in instructions for the test account below.
- **Test account:** Microsoft testers must be able to sign in. Sign-in is an
  emailed one-time code, so a plain email and password is not enough. Provide a
  dedicated synthetic production account used only for certification, and give
  testers a way to receive its code (for example a mailbox they can open with
  credentials written in the certification notes, or a reviewer-only sign-in
  path decided under spec 006/012). Never reuse a personal or team account.
  **This is the main blocker for the first submission.**

After certification, the Store page URL is the target of the website's stable
link `/preuzmi/windows` (302 redirect), so the QR code does not change when the
listing or package changes. Hosted distribution of other platforms and the
release gate (Windows after 028 acceptance) follow spec 033.

## CI and acceptance

The `windows` job in `.github/workflows/check.yml` runs on `windows-latest`,
pins Flutter 3.50.0 and verifies that the x64 release build compiles. The existing
Ubuntu `check` job owns analysis and the full Flutter test suite, so the Windows
job does not duplicate them. The `check` workflow does not upload a bundle or
publish an MSIX; Store packages come from the manual `windows-store` workflow
or a Windows workstation, as described above.

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
