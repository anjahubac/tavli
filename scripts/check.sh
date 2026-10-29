#!/usr/bin/env bash
# Pre-commit check: formatting, static analysis, tests.
# Usage: scripts/check.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> dart format (check)"
dart format --output=none --set-exit-if-changed lib test

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test

echo "OK"
