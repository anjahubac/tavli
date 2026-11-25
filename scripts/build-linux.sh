#!/usr/bin/env bash
# .deb paket za direktno preuzimanje na Linuxu (docs/development/linux.md).
# Pokreće se na Ubuntu 24.04 x86_64. Build broj je broj commitova na HEAD,
# kao za Android; verziju za korisnika (npr. 1.0.0) diže se ručno u pubspec.yaml.
#
# Usage: scripts/build-linux.sh         objava: čist main = origin/main,
#                                       secrets.prod.json
#        scripts/build-linux.sh --dev   test: bilo koja grana, secrets.dev.json
#        scripts/build-linux.sh --ci    CI: bez konfiguracije naloga (ne može
#                                       da se prijavi), samo provera paketa
#
# TAVLI_DEB_MAINTAINER (opciono): polje Maintainer, npr. "Ime <adresa>".
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "GREŠKA: $*" >&2
  exit 1
}

mode=release
case "${1:-}" in
  "") ;;
  --dev) mode=dev ;;
  --ci) mode=ci ;;
  *)
    echo "Usage: scripts/build-linux.sh [--dev|--ci]" >&2
    exit 64
    ;;
esac

[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] ||
  fail "paket se pravi samo na Linuxu x86_64 (sada: $(uname -sm))."
command -v dpkg-deb >/dev/null || fail "nema dpkg-deb (Debian/Ubuntu)."

defines=()
case $mode in
  release) config=secrets.prod.json ;;
  dev) config=secrets.dev.json ;;
  ci) config= ;;
esac
if [[ -n $config ]]; then
  # Samo postojanje; sadržaj čita Flutter pri buildu.
  [[ -f $config ]] || fail "nema $config (deli se kroz password manager)."
  defines=(--dart-define-from-file="$config")
fi

# U plitkom klonu broj commitova je premali, pa apt ne bi video novu verziju.
[[ $(git rev-parse --is-shallow-repository) == false ]] ||
  fail "plitak klon; pokreni 'git fetch --unshallow'."

if [[ $mode == release ]]; then
  branch=$(git symbolic-ref --short -q HEAD || true)
  [[ $branch == main ]] ||
    fail "objava se builduje samo sa main (sada: ${branch:-detached HEAD}). Za test: --dev."
  [[ -z $(git status --porcelain) ]] ||
    fail "ima necommitovanih izmena; paket mora da odgovara commitu."
  git fetch --quiet origin main
  [[ $(git rev-parse HEAD) == $(git rev-parse origin/main) ]] ||
    fail "lokalni main nije isti kao origin/main; pokreni 'git pull'."
fi

build_number=$(git rev-list --count HEAD)
version_name=$(sed -n 's/^version: *\([^+ ]*\).*/\1/p' pubspec.yaml)
[[ -n $version_name ]] || fail "nema 'version:' u pubspec.yaml."
version="$version_name+$build_number"

echo "==> flutter build linux ($mode, $version${config:+, $config})"
flutter build linux --release \
  --build-name="$version_name" \
  --build-number="$build_number" \
  "${defines[@]}"

bundle=build/linux/x64/release/bundle
[[ -x $bundle/tavli ]] || fail "nema $bundle/tavli posle builda."

out_dir=build/linux/deb
suffix=
[[ $mode != release ]] && suffix="-$mode"
name="tavli_${version}${suffix}_amd64"
root="$out_dir/$name"
rm -rf "$out_dir"
mkdir -p "$root/DEBIAN" "$root/opt" "$root/usr/bin" "$root/usr/share/applications"

echo "==> sadržaj paketa"
cp -a "$bundle" "$root/opt/tavli"
ln -s /opt/tavli/tavli "$root/usr/bin/tavli"
install -m 644 linux/packaging/com.tavli.tavli.desktop "$root/usr/share/applications/"

# Iste ikone kao za macOS (assets/branding), u hicolor temi pod APPLICATION_ID.
icons=macos/Runner/Assets.xcassets/AppIcon.appiconset
for size in 16 32 64 128 256 512; do
  dir="$root/usr/share/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$dir"
  install -m 644 "$icons/app_icon_$size.png" "$dir/com.tavli.tavli.png"
done

# Desktop baza, MIME keš i ikone osvežavaju se dpkg triggerima
# (desktop-file-utils, shared-mime-info, hicolor-icon-theme), pa paket nema
# postinst/postrm skripte.
chmod -R u+rwX,go+rX,go-w "$root"
installed_size=$(du -sk --exclude=DEBIAN "$root" | cut -f1)
sed -e "s/@VERSION@/$version/" \
  -e "s/@INSTALLED_SIZE@/$installed_size/" \
  -e "s/@MAINTAINER@/${TAVLI_DEB_MAINTAINER:-Tavli}/" \
  linux/packaging/control.in >"$root/DEBIAN/control"
chmod 644 "$root/DEBIAN/control"

dpkg-deb --root-owner-group -Zxz --build "$root" "$out_dir/$name.deb" >/dev/null
rm -rf "$root"

(cd "$out_dir" && sha256sum "$name.deb" >"$name.deb.sha256")

# Za GitHub Release: uvek isto ime, da .../releases/latest/download/
# tavli_amd64.deb (i /preuzmi/linux) vodi na najnoviju verziju.
if [[ $mode == release ]]; then
  cp "$out_dir/$name.deb" "$out_dir/tavli_amd64.deb"
  (cd "$out_dir" && sha256sum tavli_amd64.deb >tavli_amd64.deb.sha256)
fi

echo "==> gotovo"
echo "commit:  $(git rev-parse HEAD)"
echo "paket:   $out_dir/$name.deb"
[[ $mode == release ]] && echo "release: $out_dir/tavli_amd64.deb (+ .sha256)"
echo "SHA-256: $(cut -d' ' -f1 "$out_dir/$name.deb.sha256")"
