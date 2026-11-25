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

Raise `version` in `pubspec.yaml` before every published build: the number
after `+` is the Android `versionCode` and must grow, or Android refuses the
update.

```bash
flutter build apk --release --dart-define-from-file=secrets.prod.json
```

The output is `build/app/outputs/flutter-apk/app-release.apk`. The
`--dart-define-from-file` values are embedded in the APK and anyone can read
them, so that file must hold only public client configuration.

Confirm the signer before publishing; the SHA-256 certificate digest must match
the team key:

```bash
"$ANDROID_HOME"/build-tools/<version>/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

Publish the file's SHA-256 checksum next to the download link:

```bash
shasum -a 256 build/app/outputs/flutter-apk/app-release.apk
```

## Install for testing

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

A device that has a debug-signed Tavli installed must uninstall it first,
because the signatures differ.
