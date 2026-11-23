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

# The `dart` wrapper in flutter/bin re-checks the engine version on every call
# (on Windows through PowerShell, 3-30 s). When the cached Dart SDK already
# matches the version this Flutter checkout requires, run it directly;
# otherwise keep the wrapper so it can update the cache.
if [[ "$1" == dart ]] && flutter_bin=$(command -v flutter 2>/dev/null); then
  flutter_root=$(cd "$(dirname "$flutter_bin")/.." && pwd)
  cache=$flutter_root/bin/cache
  required=$(cat "$flutter_root/bin/internal/engine.version" 2>/dev/null | tr -d '\r' || true)
  installed=$(cat "$cache/engine-dart-sdk.stamp" 2>/dev/null | tr -d '\r' || true)
  for direct in "$cache/dart-sdk/bin/dart.exe" "$cache/dart-sdk/bin/dart"; do
    if [[ -n "$required" && "$required" == "$installed" && -x "$direct" ]]; then
      shift
      exec "$direct" "$@"
    fi
  done
fi
exec "$@"
