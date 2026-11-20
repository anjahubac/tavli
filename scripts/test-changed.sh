#!/usr/bin/env bash
# Pokreće testove na koje utiču izmenjeni fajlovi (direktno ili preko importa).
# Bez argumenata gleda fajlove spremne za commit (git add); sa argumentom
# poredi sa zadatom granom, npr. `scripts/test-changed.sh origin/dev`.
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

# Windows ograničava dužinu komandne linije. Veliki merge može imati dovoljno
# fajlova da Dart proces ne može ni da se pokrene, pa tada bezbedno vrti sve.
if (( ${#changed} > 7000 )); then
  tests=ALL
else
  # shellcheck disable=SC2086 # putanje u repou nemaju razmake
  tests=$(scripts/with-sdk-env.sh dart run scripts/affected_tests.dart $changed)
fi

ui=packages/tavli_ui

if [[ "$tests" == "ALL" ]]; then
  echo "==> flutter test (svi testovi: izmena važi za ceo projekat)"
  scripts/with-sdk-env.sh flutter test
  echo "==> flutter test ($ui)"
  (cd "$ui" && ../../scripts/with-sdk-env.sh flutter test)
  exit 0
fi

app_tests=$(grep -v "^$ui/" <<<"$tests" || true)
ui_tests=$(grep "^$ui/" <<<"$tests" | sed "s#^$ui/##" || true)

if [[ -z "$app_tests" && -z "$ui_tests" ]]; then
  echo "==> flutter test: izmene ne utiču ni na jedan test"
fi
if [[ -n "$app_tests" ]]; then
  echo "==> flutter test ($(wc -l <<<"$app_tests" | tr -d ' ') fajlova)"
  # shellcheck disable=SC2086
  scripts/with-sdk-env.sh flutter test $app_tests
fi
if [[ -n "$ui_tests" ]]; then
  echo "==> flutter test $ui ($(wc -l <<<"$ui_tests" | tr -d ' ') fajlova)"
  # shellcheck disable=SC2086
  (cd "$ui" && ../../scripts/with-sdk-env.sh flutter test $ui_tests)
fi
