# Android release builds

Tavli builds an Android APK for direct download (sideloading) from the Tavli
website. Google Play publication, hosting and update notices are separate
decisions owned by spec 033; this page covers signing and building only.

## Signing key

A release APK must be signed with the team's own key. Android installs an
update only when it is signed with the same key as the installed app, so the
first public APK fixes the key for the life of the app. A lost key means users
must uninstall and reinstall.

Create the key once, outside the repository, and store the keystore file and
both passwords in the team password manager:

```bash
keytool -genkeypair -v -keystore ~/tavli-keys/tavli-upload.jks -storetype JKS -keyalg RSA -keysize 4096 -validity 10000 -alias tavli-upload
```

Copy `android/key.properties.example` to `android/key.properties` (gitignored)
and fill in the keystore path, alias and passwords. `storeFile` may be absolute
or relative to `android/`.

Without `android/key.properties` the release build falls back to the debug key.
Gradle logs a warning, which Flutter shows only with `flutter build apk -v`, so
check the signer as described below. That build is only for local testing and
CI; never publish it.

## Build

The version shown to people (`1.0.0` in `version: 1.0.0+1` in `pubspec.yaml`)
is raised by hand for a release. The build number after `+` is the Android
`versionCode` and must grow, or Android refuses the update. The build script
sets it to the commit count of `HEAD` (`git rev-list --count HEAD`) through
`--build-number`, so `pubspec.yaml` is not edited for it. The count only grows
on `main`, so published APKs are built from `main` only.

```bash
scripts/build-android.sh
```

For a published build the script requires a clean `main` equal to
`origin/main`, a full (not shallow) clone, `secrets.prod.json` and
`android/key.properties`. It builds the release APK, copies it to
`build/app/outputs/flutter-apk/tavli-<version>+<build>.apk`, prints the
certificate's SHA-256 digest, fails on a debug signature and prints the file's
SHA-256 checksum to publish next to the download link. Set
`TAVLI_UPLOAD_CERT_SHA256` to the team certificate digest to make the script
compare the signer as well.

A test build from any branch against `tavli-dev` uses `--dev`; the debug key is
allowed there with a warning, and such an APK is never published:

```bash
scripts/build-android.sh --dev
```

The `--dart-define-from-file` values are embedded in the APK and anyone can
read them, so that file must hold only public client configuration.

The same steps by hand:

```bash
flutter build apk --release --build-number=$(git rev-list --count HEAD) --dart-define-from-file=secrets.prod.json
```

```bash
"$ANDROID_HOME"/build-tools/<version>/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

```bash
shasum -a 256 build/app/outputs/flutter-apk/app-release.apk
```

## Install for testing

```bash
adb install -r build/app/outputs/flutter-apk/tavli-<version>+<build>.apk
```

A device that has a debug-signed Tavli installed must uninstall it first,
because the signatures differ.
