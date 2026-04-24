#!/usr/bin/env bats
# Edge cases (Bash).

load test_helper

@test "cursor sync-agent-guidelines: same -i and -o skips cross-root AGENTS copy and exits 0" {
  GSH="${REPO_ROOT}/scripts/cursor/sync-agent-guidelines.sh"
  SAME="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_same.XXXXXX")"
  cp "$TEST_SRC/AGENTS.md" "$SAME/AGENTS.md"
  run bash "$GSH" -i "$SAME" -o "$SAME"
  rm -rf "$SAME"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip"* ]] || [[ "$output" == *"skip AGENTS"* ]]
}

@test "common.sh: parse_io_args rejects missing -o" {
  # Indirectly via a script that uses parse_io_args
  ASH="${REPO_ROOT}/scripts/cursor/sync-agents.sh"
  run bash "$ASH" -i "$TEST_SRC/agents"
  [ "$status" -eq 2 ]
}

@test "sync-all: run_sync handles items + clean without unbound array (regression)" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor --items alpha --clean
  [ "$status" -eq 0 ]
  [ -d "$TEST_OUT/.cursor/skills/alpha" ]
  [ ! -d "$TEST_OUT/.cursor/skills/beta" ]
}
