#!/usr/bin/env bash
# Registruje Tavli kao aplikaciju koja otvara tavli:// linkove na Linuxu
# (npr. "Potvrdi adresu" iz mejla). Linux build nema instaler, pa ovo
# radi jednom po mašini i posle svake promene putanje build-a.
#
#   scripts/linux-register-links.sh            # debug bundle (flutter run -d linux)
#   scripts/linux-register-links.sh release    # release bundle
#   scripts/linux-register-links.sh /put/do/bundle
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
arch="$(uname -m)"
[[ "$arch" == "x86_64" ]] && arch="x64"
[[ "$arch" == "aarch64" ]] && arch="arm64"

case "${1:-debug}" in
  debug | profile | release) bundle="$root/build/linux/$arch/${1:-debug}/bundle" ;;
  *) bundle="$(cd "$1" && pwd)" ;;
esac

binary="$bundle/tavli"
if [[ ! -x "$binary" ]]; then
  echo "Nema $binary — prvo pokreni 'flutter build linux' ili 'flutter run -d linux'." >&2
  exit 1
fi

# Ime fajla = APPLICATION_ID iz linux/CMakeLists.txt, da GNOME poveže prozor.
desktop_id="com.tavli.tavli.desktop"
apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$apps"

cat >"$apps/$desktop_id" <<EOF
[Desktop Entry]
Type=Application
Name=Tavli
Exec="$binary" %u
Icon=$bundle/data/flutter_assets/assets/branding/tavli-auth-icon.png
Terminal=false
Categories=Utility;
MimeType=x-scheme-handler/tavli;
StartupWMClass=com.tavli.tavli
EOF

update-desktop-database "$apps" 2>/dev/null || true
xdg-mime default "$desktop_id" x-scheme-handler/tavli

echo "tavli:// sada otvara: $(xdg-mime query default x-scheme-handler/tavli) → $binary"
