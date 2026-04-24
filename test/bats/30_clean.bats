#!/usr/bin/env bats
# --clean pruning behaviour (Bash).

load test_helper

@test "sync-all --clean: removing rule from source drops stale .cursor rule file" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.cursor/rules/rb.mdc" ]
  rm -f "$TEST_SRC/rules/rb.md"
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor --clean
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.cursor/rules/ra.mdc" ]
  [ ! -f "$TEST_OUT/.cursor/rules/rb.mdc" ]
}

@test "sync-all --clean: removing skill from source drops stale skill dir" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor
  [ "$status" -eq 0 ]
  [ -d "$TEST_OUT/.cursor/skills/beta" ]
  rm -rf "$TEST_SRC/skills/beta"
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor --clean
  [ "$status" -eq 0 ]
  [ -d "$TEST_OUT/.cursor/skills/alpha" ]
  [ ! -d "$TEST_OUT/.cursor/skills/beta" ]
}

@test "claude sync-rules: accepts --clean and remains no-op" {
  RSH="${REPO_ROOT}/scripts/claude/sync-rules.sh"
  run bash "$RSH" -i "$TEST_SRC/rules" -o "$TEST_OUT" --clean
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped"* ]]
}

@test "junie sync-rules: accepts --clean and remains no-op" {
  RSH="${REPO_ROOT}/scripts/junie/sync-rules.sh"
  run bash "$RSH" -i "$TEST_SRC/rules" -o "$TEST_OUT" --clean
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped"* ]]
}
