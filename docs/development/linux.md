# Linux development

The Linux target is an ordinary Flutter GTK runner. There is no installer or
package yet; public distribution is deferred to spec 033.

## Build and run

```bash
flutter build linux --debug
flutter run -d linux
```

The `linux-build` job in `.github/workflows/check.yml` builds the debug bundle
on Ubuntu 24.04 and uploads it as an artifact for seven days; it does not run
the app on a device. The bundle is under `build/linux/<arch>/<mode>/bundle/`. Pass account
configuration with `--dart-define-from-file` as described in `AGENTS.md`.

## Email confirmation links (`tavli://`)

"Potvrdi adresu" in the confirmation email opens `tavli://auth-callback?code=…`.
Without an installer, the desktop does not know which app handles `tavli://`,
so register the built bundle once per machine (and again if its path changes):

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
