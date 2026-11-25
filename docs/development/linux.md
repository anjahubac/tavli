# Linux development and packaging

The Linux target is an ordinary Flutter GTK runner. The first supported system
is Ubuntu 24.04 LTS on x86_64. People install Tavli from a `.deb` package
downloaded from the Tavli website; there is no store or apt repository yet,
so updates are a new download. Release sequencing and evidence belong to
spec 033 (FR-106).

## Build and run

```bash
flutter build linux --debug
flutter run -d linux
```

The bundle is under `build/linux/<arch>/<mode>/bundle/`. Pass account
configuration with `--dart-define-from-file` as described in `AGENTS.md`.

## Debian package

`scripts/build-linux.sh` builds the release bundle and wraps it in a `.deb`
with the system `dpkg-deb`. It runs only on Linux x86_64 (Ubuntu 24.04), not
on macOS. The package installs:

| Path | Content |
|---|---|
| `/opt/tavli/` | the release bundle (`tavli`, `lib/`, `data/`) |
| `/usr/bin/tavli` | symlink to `/opt/tavli/tavli` |
| `/usr/share/applications/com.tavli.tavli.desktop` | app menu entry and `tavli://` handler |
| `/usr/share/icons/hicolor/<size>/apps/com.tavli.tavli.png` | app icon, 16–512 px |

The desktop entry and the control template are in `linux/packaging/`. The
desktop file name and icon name equal `APPLICATION_ID` (`com.tavli.tavli`) from
`linux/CMakeLists.txt`, so GNOME matches the window to the menu entry. Icons
are the macOS app icon PNGs (`macos/Runner/Assets.xcassets/AppIcon.appiconset`),
the same artwork as `assets/branding/tavli-app-icon.svg` with platform padding.

The package has no maintainer scripts. dpkg triggers from
`desktop-file-utils`, `shared-mime-info` and `hicolor-icon-theme` refresh the
desktop database, the `x-scheme-handler/tavli` association and the icon cache.

`Depends` lists GTK 3, GLib, `libsecret-1-0` and `libepoxy0`, with the
Ubuntu 24.04 `t64` package names first. `Recommends` (installed by default by
apt) adds a Secret Service keyring (`gnome-keyring` or KWallet), `pulseaudio-utils`
and `ffmpeg` for voice recipe drafting, and `xdg-utils`. Without a running
keyring Tavli cannot keep the session.

### Versioning

The package version is `<version>+<build>`: `version` from `pubspec.yaml`
without its build part, and the commit count of `HEAD` as build number, the
same rule as Android. apt installs a downloaded package over an older one only
when its version is higher, so published packages are built from `main` only.

### Build

```bash
scripts/build-linux.sh
```

For a published build the script requires a clean `main` equal to
`origin/main`, a full (not shallow) clone and `secrets.prod.json`. The result
is `build/linux/deb/tavli_<version>+<build>_amd64.deb` and a `.sha256` file
next to it, plus the constant-name copy described under Hosting. The script
prints the commit SHA and the checksum; record both as release evidence.

A test build from any branch against `tavli-dev`:

```bash
scripts/build-linux.sh --dev
```

It writes `tavli_<version>+<build>-dev_amd64.deb`; never publish it. The
`--dart-define-from-file` values are embedded in the bundle and anyone can read
them, so that file must hold only public client configuration. Set
`TAVLI_DEB_MAINTAINER` to fill the package's `Maintainer` field (default
`Tavli`).

### CI

The `linux-build` job in `.github/workflows/check.yml` runs on Ubuntu 24.04 on
every PR. It validates the desktop entry, runs `scripts/build-linux.sh --ci`
(no account configuration, so that package cannot sign in), checks the
checksum, installs the package with apt, checks the installed files, the
`tavli://` association and that every bundled library resolves, then removes
it. The `.deb` and its checksum are uploaded as the `tavli-linux-deb` artifact
for seven days. The job does not start the app and publishes nothing.

## Install and test on Ubuntu

Install the downloaded file through apt so dependencies are resolved:

```bash
sudo apt install ./tavli_<version>+<build>_amd64.deb
```

Open **Tavli** from the app menu (or run `tavli`). Request the sign-in email,
then use the confirmation link from the same desktop session; it opens
`tavli://auth-callback?code=…`. Check the association:

```bash
xdg-mime query default x-scheme-handler/tavli
```

It should print `com.tavli.tavli.desktop`. Remove the app with:

```bash
sudo apt remove tavli
```

Removing the package keeps account data in the home directory and the session
in the keyring, as sign-out does on other platforms.

If `scripts/linux-register-links.sh` was used on the same machine, its
`~/.local/share/applications/com.tavli.tavli.desktop` overrides the installed
entry and points links at a build directory. Delete that file before testing
the package.

## Hosting

Published packages are assets of a GitHub Release on the public
`anjahubac/tavli` repository: one release per Linux version, tagged
`linux-v<version>` on the released `main` commit (Android uses
`android-v<version>`). The release build also writes
`build/linux/deb/tavli_amd64.deb` and `tavli_amd64.deb.sha256`, a copy with a
constant name; upload both to the release. Create Linux releases with
`--latest=false`: GitHub's `releases/latest` belongs to one release only, and
platforms are released separately.

The website's stable link `/preuzmi/linux` answers with a 302 redirect to the
current release's file (`site/_redirects`, served by the `welcome` Worker), so
the QR code does not change between releases:

```text
https://github.com/anjahubac/tavli/releases/download/linux-v<version>/tavli_amd64.deb
```

For a new Linux release, upload the assets first, then change the tag in
`site/_redirects` through a PR. GitHub serves the file as
`application/octet-stream`; browsers still save it as a `.deb`.

## Email confirmation links (`tavli://`)

"Potvrdi adresu" in the confirmation email opens `tavli://auth-callback?code=…`.
The installed package registers Tavli for `tavli://` through `MimeType` in its
desktop entry. A development build has no desktop entry, so register the built
bundle once per machine (and again if its path changes):

```bash
scripts/linux-register-links.sh            # debug bundle
scripts/linux-register-links.sh release    # release bundle
```

The script writes `~/.local/share/applications/com.tavli.tavli.desktop` with
`MimeType=x-scheme-handler/tavli` and makes it the default handler via
`xdg-mime`. Check it with `xdg-open 'tavli://auth-callback?code=test'`.

The runner (`linux/runner/my_application.cc`) is a single-instance
`GApplication` with `G_APPLICATION_HANDLES_COMMAND_LINE`. A second launch with a
link forwards its arguments to the running Tavli over D-Bus and exits;
`app_links` reads the link from the `command-line` signal and the window is
presented. The window and plugins are created in `startup`, before the first
`command-line` signal, so the link that cold-starts the app is not lost.
