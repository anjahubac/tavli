#!/usr/bin/env bash
# Flutter/Dart inspect the SDK's own Git checkout. A worktree hook exports
# repository-local Git variables; keep those out of SDK subprocesses only.
# Callers retain their original Git environment for staged-file selection.
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: with-sdk-env.sh <command> [args...]" >&2
  exit 64
fi

git_local_vars=$(git rev-parse --local-env-vars)
while IFS= read -r git_local_var; do
  unset "$git_local_var"
done <<< "$git_local_vars"
exec "$@"
