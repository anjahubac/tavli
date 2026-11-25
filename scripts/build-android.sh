#!/usr/bin/env bash
# Release APK za direktno preuzimanje (docs/development/android.md).
# Build broj (Android versionCode) je broj commitova na HEAD, pa raste sam i
# pubspec.yaml se ne menja; verziju za korisnika (npr. 1.0.0) diže se ručno.
#
# Usage: scripts/build-android.sh         objava: čist main = origin/main,
#                                         secrets.prod.json, timski ključ
#        scripts/build-android.sh --dev   test: bilo koja grana,
#                                         secrets.dev.json, ključ nije obavezan
#
# TAVLI_UPLOAD_CERT_SHA256 (opciono): očekivani SHA-256 otisak timskog
# sertifikata; ako je zadat, potpis APK-a mora da se poklopi.
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
  *)
    echo "Usage: scripts/build-android.sh [--dev]" >&2
    exit 64
    ;;
esac

config=secrets.prod.json
[[ $mode == dev ]] && config=secrets.dev.json
# Samo postojanje; sadržaj čita Flutter pri buildu.
[[ -f $config ]] || fail "nema $config (deli se kroz password manager)."

# U plitkom klonu broj commitova je premali, pa bi Android odbio ažuriranje.
[[ $(git rev-parse --is-shallow-repository) == false ]] ||
  fail "plitak klon; pokreni 'git fetch --unshallow'."

if [[ $mode == release ]]; then
  branch=$(git symbolic-ref --short -q HEAD || true)
  [[ $branch == main ]] ||
    fail "objava se builduje samo sa main (sada: ${branch:-detached HEAD}). Za test: --dev."
  [[ -z $(git status --porcelain) ]] ||
    fail "ima necommitovanih izmena; APK mora da odgovara commitu."
  git fetch --quiet origin main
  [[ $(git rev-parse HEAD) == $(git rev-parse origin/main) ]] ||
    fail "lokalni main nije isti kao origin/main; pokreni 'git pull'."
  [[ -f android/key.properties ]] ||
    fail "nema android/key.properties; bez njega APK dobija debug potpis."
elif [[ ! -f android/key.properties ]]; then
  echo "UPOZORENJE: nema android/key.properties; APK će imati debug potpis." >&2
fi

build_number=$(git rev-list --count HEAD)
version_name=$(sed -n 's/^version: *\([^+ ]*\).*/\1/p' pubspec.yaml)
[[ -n $version_name ]] || fail "nema 'version:' u pubspec.yaml."

echo "==> flutter build apk ($mode, $version_name+$build_number, $config)"
scripts/with-sdk-env.sh flutter build apk --release \
  --build-number="$build_number" \
  --dart-define-from-file="$config"

apk_dir=build/app/outputs/flutter-apk
out="$apk_dir/tavli-$version_name+$build_number.apk"
[[ $mode == dev ]] && out="$apk_dir/tavli-$version_name+$build_number-dev.apk"
cp "$apk_dir/app-release.apk" "$out"

echo "==> potpis"
sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
apksigner=$(find "$sdk/build-tools" -maxdepth 2 -name apksigner 2>/dev/null |
  sort -V | tail -n 1)
if [[ -z $apksigner ]]; then
  [[ $mode == dev ]] || fail "apksigner nije nađen u $sdk/build-tools; potpis nije proveren."
  echo "UPOZORENJE: apksigner nije nađen; potpis nije proveren." >&2
else
  certs=$("$apksigner" verify --print-certs "$out")
  # Stariji apksigner: "Signer #1 certificate SHA-256 digest: …",
  # noviji: "V2 Signer: certificate SHA-256 digest: …".
  digest=$(sed -n 's/^.*certificate SHA-256 digest: //p' <<< "$certs" | head -n 1)
  [[ -n $digest ]] || fail "apksigner nije ispisao SHA-256 sertifikata."
  echo "SHA-256 sertifikata: $digest"
  if grep -q 'CN=Android Debug' <<< "$certs"; then
    [[ $mode == dev ]] || fail "APK je potpisan debug ključem; ne objavljuj ga."
    echo "UPOZORENJE: debug potpis; samo za lokalni test." >&2
  fi
  if [[ -n ${TAVLI_UPLOAD_CERT_SHA256:-} ]]; then
    expected=$(tr -d ': ' <<< "$TAVLI_UPLOAD_CERT_SHA256" | tr '[:upper:]' '[:lower:]')
    [[ $digest == "$expected" ]] ||
      fail "potpis se ne poklapa sa TAVLI_UPLOAD_CERT_SHA256."
    echo "Potpis odgovara timskom ključu."
  fi
fi

echo "==> SHA-256 fajla (objavi pored linka)"
shasum -a 256 "$out"
echo "OK: $out"
