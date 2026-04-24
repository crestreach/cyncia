#!/usr/bin/env bats
# End-to-end sync-all.sh (Bash) tests.

load test_helper

@test "sync-all: cursor only produces .cursor tree and key files" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/AGENTS.md" ]
  [ -f "$TEST_OUT/.cursor/agents/one.md" ]
  [ -d "$TEST_OUT/.cursor/skills/alpha" ]
  [ -d "$TEST_OUT/.cursor/skills/beta" ]
  [ -f "$TEST_OUT/.cursor/rules/ra.mdc" ]
  [ -f "$TEST_OUT/.cursor/rules/rb.mdc" ]
  [ ! -d "$TEST_OUT/.claude" ]
}

@test "sync-all: all four tool dirs are created" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [ -d "$TEST_OUT/.cursor" ]
  [ -d "$TEST_OUT/.claude" ]
  [ -d "$TEST_OUT/.github" ]
  [ -d "$TEST_OUT/.junie" ]
  [ -f "$TEST_OUT/CLAUDE.md" ]
  [ -f "$TEST_OUT/.github/copilot-instructions.md" ]
  [ -f "$TEST_OUT/.junie/AGENTS.md" ]
}

@test "sync-all: missing -o exits 2" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC"
  [ "$status" -eq 2 ]
}

@test "sync-all: unknown flag exits 2" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --not-a-real-flag-xyz
  [ "$status" -eq 2 ]
}

@test "sync-all: --help exits 0" {
  run bash "$SYNC_ALL_SH" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "sync-all: input tree without AGENTS.md fails" {
  BAD_SRC="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_bad.XXXXXX")"
  mkdir -p "$BAD_SRC/agents" "$BAD_SRC/skills" "$BAD_SRC/rules"
  echo "x" > "$BAD_SRC/agents/x.md"
  run bash "$SYNC_ALL_SH" -i "$BAD_SRC" -o "$TEST_OUT"
  rm -rf "$BAD_SRC"
  [ "$status" -ne 0 ]
}
