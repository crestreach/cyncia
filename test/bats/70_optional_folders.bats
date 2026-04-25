#!/usr/bin/env bats
# Each of agents/, skills/, rules/, mcp-servers/ is optional. sync-all should
# succeed when they are absent; agents/skills/rules are skipped with a console
# note instead of erroring.

load 'test_helper.bash'

@test "sync-all: only AGENTS.md (no agents/skills/rules) succeeds" {
  rm -rf "$TEST_SRC/agents" "$TEST_SRC/skills" "$TEST_SRC/rules"
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor
  [ "$status" -eq 0 ]
  [[ "$output" == *"agents: skipped"* ]]
  [[ "$output" == *"skills: skipped"* ]]
  [[ "$output" == *"rules: skipped"* ]]
  # Guidelines step still runs and writes the AGENTS.md copy.
  [ -f "$TEST_OUT/AGENTS.md" ]
}

@test "sync-all: missing only rules/ skips rules step but still syncs the rest" {
  rm -rf "$TEST_SRC/rules"
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor
  [ "$status" -eq 0 ]
  [[ "$output" == *"rules: skipped"* ]]
  [ -d "$TEST_OUT/.cursor/agents" ]
  [ -d "$TEST_OUT/.cursor/skills" ]
  [ ! -d "$TEST_OUT/.cursor/rules" ]
}

@test "sync-all: missing only agents/ skips agents step but still syncs skills and rules" {
  rm -rf "$TEST_SRC/agents"
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor
  [ "$status" -eq 0 ]
  [[ "$output" == *"agents: skipped"* ]]
  [ ! -d "$TEST_OUT/.cursor/agents" ]
  [ -d "$TEST_OUT/.cursor/skills" ]
  [ -d "$TEST_OUT/.cursor/rules" ]
}
