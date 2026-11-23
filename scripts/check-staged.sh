#!/usr/bin/env bash
# Brza provera pre commita: formatiranje Dart fajlova spremnih za commit
# (git add) i pravila uvoza tavli_ui. Bez analize i testova: njih pokreće
# pre-push hook (scripts/check-push.sh), a ceo skup CI.
# Provera se vrti nad radnim stablom, kao i scripts/test-changed.sh.
# Usage: scripts/check-staged.sh
set -euo pipefail

cd "$(dirname "$0")/.."

# Isti folderi kao `dart format` u scripts/check.sh.
dart_files=$(git diff --cached --name-only --diff-filter=ACMR -- \
  'lib/*.dart' 'test/*.dart' 'scripts/*.dart' 'packages/*.dart')

if [[ -z "$dart_files" ]]; then
  echo "==> nema Dart izmena za commit"
  exit 0
fi

echo "==> dart format (check, $(wc -l <<<"$dart_files" | tr -d ' ') fajlova)"
# shellcheck disable=SC2086 # putanje u repou nemaju razmake
scripts/with-sdk-env.sh dart format --output=none --set-exit-if-changed $dart_files

echo "==> javni ulaz tavli_ui (bez uvoza iz src/)"
python3 scripts/check_ui_imports.py

echo "==> preseljeni ekrani samo sa komponentama iz tavli_ui"
python3 scripts/check_ui_area.py

echo "OK"
