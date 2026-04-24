# Bats helper — loaded by each .bats file in this directory.
# shellcheck shell=bash

# Repo root: test/bats -> test -> repository root
test_helper::repo_root() {
  echo "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)"
}

export REPO_ROOT
REPO_ROOT="$(test_helper::repo_root)"
export REPO_ROOT

FIXTURE_TWO="${REPO_ROOT}/test/fixtures/two-skills"
SYNC_ALL_SH="${REPO_ROOT}/scripts/sync-all.sh"
export FIXTURE_TWO SYNC_ALL_SH

setup() {
  TEST_SRC="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_src.XXXXXX")"
  TEST_OUT="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_out.XXXXXX")"
  if [[ -d "$FIXTURE_TWO" ]]; then
    cp -R "${FIXTURE_TWO}/." "$TEST_SRC/"
  fi
}

teardown() {
  if [[ -n "${TEST_SRC:-}" && -d "$TEST_SRC" ]]; then
    rm -rf "$TEST_SRC"
  fi
  if [[ -n "${TEST_OUT:-}" && -d "$TEST_OUT" ]]; then
    rm -rf "$TEST_OUT"
  fi
}
