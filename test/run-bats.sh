#!/usr/bin/env bash
# Run Bats tests. Requires: https://github.com/bats-core/bats-core
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if ! command -v bats >/dev/null 2>&1; then
  echo "bats is not on PATH. Install bats-core, then re-run: $0" >&2
  echo "  macOS (Homebrew): brew install bats-core" >&2
  exit 1
fi
exec bats test/bats
