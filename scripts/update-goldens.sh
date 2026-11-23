#!/usr/bin/env bash
# Pravi nove slike za testove izgleda (packages/tavli_ui/test/goldens) u
# Linux kontejneru sa istom verzijom Flutter-a kao CI, jer se tekst na
# svakom sistemu iscrtava malo drugačije. Traži Docker.
#
# Usage: scripts/update-goldens.sh          nove slike
#        scripts/update-goldens.sh --check  samo poredi, kao CI
# Posle pokretanja pregledaj izmenjene slike (git diff) pre commit-a.
set -euo pipefail

cd "$(dirname "$0")/.."

flutter_version=$(sed -n "s/^ *flutter-version: '\(.*\)'/\1/p" .github/workflows/check.yml | head -n 1)
image=ubuntu:24.04
# Isti paket SDK-a koji CI (subosito/flutter-action) skida; čuva se u
# Docker volumenu, pa se skida samo prvi put.
sdk_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${flutter_version}-stable.tar.xz"
goldens=packages/tavli_ui/test/goldens
update=--update-goldens
if [[ "${1:-}" == "--check" ]]; then update=; fi
mkdir -p "$goldens"

echo "==> Flutter $flutter_version na $image (linux/amd64, kao CI)"
# Repo se kopira u kontejner, da lokalni .dart_tool i build ostanu netaknuti;
# napolje izlaze samo slike.
docker run --rm --platform linux/amd64 \
  -v "$PWD:/src:ro" \
  -v "$PWD/$goldens:/out" \
  -v "tavli-flutter-$flutter_version:/opt/sdk" \
  -e SDK_URL="$sdk_url" \
  -e UPDATE="$update" \
  "$image" bash -euo pipefail -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq >/dev/null
    apt-get install -y -qq git curl xz-utils unzip ca-certificates >/dev/null
    if [[ ! -x /opt/sdk/flutter/bin/flutter ]]; then
      curl -fsSL "$SDK_URL" | tar -xJ -C /opt/sdk
    fi
    git config --global --add safe.directory /opt/sdk/flutter
    export PATH=/opt/sdk/flutter/bin:$PATH
    flutter --version --suppress-analytics > /tmp/flutter-version && head -1 /tmp/flutter-version
    mkdir /work
    cd /src
    tar --exclude=./build --exclude=./.dart_tool \
      --exclude=./packages/tavli_ui/build --exclude=./packages/tavli_ui/.dart_tool \
      --exclude="./secrets*.json" -cf - . | tar -xf - -C /work
    cd /work
    flutter pub get >/dev/null
    cd packages/tavli_ui
    # shellcheck disable=SC2086 # prazan UPDATE znači samo poređenje
    # Dva testa odjednom: sa više njih emulirani amd64 kontejner na Apple
    # računaru ume da zastane posle poslednjeg fajla.
    flutter test --tags golden -j 2 $UPDATE
    if [[ -n "$UPDATE" ]]; then
      rm -f /out/*.png
      cp test/goldens/*.png /out/
    fi
  '
echo "==> slike: $goldens"
