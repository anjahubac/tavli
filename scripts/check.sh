#!/usr/bin/env bash
# Brza provera: formatiranje, javni ulaz paketa tavli_ui i statička analiza
# (bez testova).
# Testovi idu kroz pre-commit hook (scripts/test-changed.sh), a ceo skup
# pokreće CI; lokalno ceo skup: `flutter test`.
# Usage: scripts/check.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> dart format (check)"
scripts/with-sdk-env.sh dart format --output=none --set-exit-if-changed lib test scripts packages

echo "==> javni ulaz tavli_ui (bez uvoza iz src/)"
python3 scripts/check_ui_imports.py

echo "==> flutter analyze (aplikacija i packages/)"
scripts/with-sdk-env.sh flutter analyze

echo "OK"
