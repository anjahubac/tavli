#!/usr/bin/env bash
# Provera pre push-a: `flutter analyze` i testovi na koje utiču commitovi koji
# se šalju. Git šalje na stdin po red za svaku granu:
#   <lokalni ref> <lokalni sha> <udaljeni ref> <udaljeni sha>
# Poredi se sa onim što je već na serveru; nova grana se poredi sa
# origin/dev. Brisanje grane i tagovi se preskaču.
# Usage (iz .githooks/pre-push): scripts/check-push.sh < refs
set -euo pipefail

cd "$(dirname "$0")/.."

ranges=()

while read -r local_ref local_sha _remote_ref remote_sha; do
  [[ -z "${local_sha:-}" || "$local_sha" =~ ^0+$ ]] && continue
  [[ "$local_ref" == refs/tags/* ]] && continue
  if [[ ! "$remote_sha" =~ ^0+$ ]] && git cat-file -e "$remote_sha^{commit}" 2>/dev/null; then
    base=$remote_sha
  else
    base=$(git merge-base origin/dev "$local_sha" 2>/dev/null || true)
  fi
  if [[ -z "$base" ]]; then
    # Bez zajedničke osnove nema pouzdanog spiska izmena: proveri sve.
    ranges+=(ALL)
  else
    ranges+=("$base..$local_sha")
  fi
done

if [[ ${#ranges[@]} -eq 0 ]]; then
  echo "==> pre-push: nema grana za proveru"
  exit 0
fi

# Analiza samo kada su se menjali Dart fajlovi ili podešavanja paketa.
needs_analyze=false
for range in "${ranges[@]}"; do
  if [[ "$range" == ALL ]] ||
    git diff --name-only --diff-filter=ACMR "$range" |
    grep -qE '\.dart$|(^|/)pubspec\.(yaml|lock)$|(^|/)analysis_options\.yaml$'; then
    needs_analyze=true
  fi
done

if $needs_analyze; then
  echo "==> flutter analyze (aplikacija i packages/)"
  scripts/with-sdk-env.sh flutter analyze
else
  echo "==> flutter analyze: nema Dart izmena"
fi

for range in "${ranges[@]}"; do
  if [[ "$range" == ALL ]]; then
    scripts/test-changed.sh --all
  else
    scripts/test-changed.sh "$range"
  fi
done

echo "OK"
