#!/usr/bin/env bash
# Puna provera: formatiranje celog repoa, javni ulaz paketa tavli_ui,
# preseljeni ekrani bez sirovih Material widgeta i statička analiza
# (bez testova). Pokreće je CI; lokalno je pokrivaju hookovi:
# pre-commit (scripts/check-staged.sh) i pre-push (scripts/check-push.sh,
# analiza + pogođeni testovi). Lokalno ceo skup: `flutter test`.
# Usage: scripts/check.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> dart format (check)"
scripts/with-sdk-env.sh dart format --output=none --set-exit-if-changed lib test scripts packages

echo "==> javni ulaz tavli_ui (bez uvoza iz src/)"
python3 scripts/check_ui_imports.py

echo "==> preseljeni ekrani samo sa komponentama iz tavli_ui"
python3 scripts/check_ui_area.py

echo "==> flutter analyze (aplikacija i packages/)"
scripts/with-sdk-env.sh flutter analyze

echo "OK"
