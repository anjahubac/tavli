# Linux development

Initial target: Ubuntu 24.04 LTS, x86_64, with Flutter 3.50.0 stable.

Install build packages:

```sh
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev
```

Build and run:

```sh
flutter pub get
flutter build linux --debug
build/linux/x64/debug/bundle/tavli
```

The bundle includes Flutter and app/plugin libraries. The host needs GTK and
`libsecret-1-0`; secure session/key storage also needs an active desktop keyring
providing Secret Service (for example GNOME Keyring or KWallet). File picking
uses the desktop file chooser. Camera capture is not supported on Linux.

This is a development bundle, not an installer or published release artifact.
