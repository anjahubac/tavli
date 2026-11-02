#!/usr/bin/env bash
# Pokreće testove na koje utiču izmenjeni fajlovi (direktno ili preko importa).
# Bez argumenata gleda fajlove spremne za commit (git add); sa argumentom
# poredi sa zadatom granom, npr. `scripts/test-changed.sh origin/main`.
# Testovi se vrte nad radnim stablom, ne samo nad onim što je u indeksu.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -gt 0 ]]; then
  changed=$(git diff --name-only --diff-filter=ACMR "$1"...HEAD)
else
  changed=$(git diff --cached --name-only --diff-filter=ACMR)
fi

if [[ -z "$changed" ]]; then
  echo "==> flutter test: nema izmenjenih fajlova"
  exit 0
fi

# shellcheck disable=SC2086 # putanje u repou nemaju razmake
tests=$(dart run scripts/affected_tests.dart $changed)

if [[ "$tests" == "ALL" ]]; then
  echo "==> flutter test (svi testovi: izmena važi za ceo projekat)"
  flutter test
elif [[ -z "$tests" ]]; then
  echo "==> flutter test: izmene ne utiču ni na jedan test"
else
  echo "==> flutter test ($(wc -l <<<"$tests" | tr -d ' ') fajlova)"
  # shellcheck disable=SC2086
  flutter test $tests
fi
