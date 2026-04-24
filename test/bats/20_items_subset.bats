#!/usr/bin/env bats
# --items subset behaviour (Bash).

load test_helper

@test "sync-all: --items only syncs listed skill" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor --items alpha
  [ "$status" -eq 0 ]
  [ -d "$TEST_OUT/.cursor/skills/alpha" ]
  [ ! -d "$TEST_OUT/.cursor/skills/beta" ]
}

@test "sync-all: --items one,alpha,ra limits agent, skill, and rule together" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor --items one,alpha,ra
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.cursor/agents/one.md" ]
  [ -d "$TEST_OUT/.cursor/skills/alpha" ]
  [ -f "$TEST_OUT/.cursor/rules/ra.mdc" ]
  [ ! -d "$TEST_OUT/.cursor/skills/beta" ]
  [ ! -f "$TEST_OUT/.cursor/rules/rb.mdc" ]
}

@test "sync-all: --items multiple skills" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor --items alpha,beta
  [ "$status" -eq 0 ]
  [ -d "$TEST_OUT/.cursor/skills/alpha" ]
  [ -d "$TEST_OUT/.cursor/skills/beta" ]
}

@test "cursor sync-rules: --items limits generated .mdc files" {
  RSH="${REPO_ROOT}/scripts/cursor/sync-rules.sh"
  run bash "$RSH" -i "$TEST_SRC/rules" -o "$TEST_OUT" --items ra
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.cursor/rules/ra.mdc" ]
  [ ! -f "$TEST_OUT/.cursor/rules/rb.mdc" ]
}

@test "sync-all: --items ra for rules; without --clean leaves stale rb instruction from prior full copilot run" {
  # First: generate both Copilot instruction files
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools copilot
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.github/instructions/ra.instructions.md" ]
  [ -f "$TEST_OUT/.github/instructions/rb.instructions.md" ]
  # Second: only ra — Copilot should not remove rb without --clean
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools copilot --items ra
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.github/instructions/ra.instructions.md" ]
  [ -f "$TEST_OUT/.github/instructions/rb.instructions.md" ]
}

@test "sync-all: --items ra with --clean drops rb copilot instruction" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools copilot
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.github/instructions/rb.instructions.md" ]
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools copilot --items ra --clean
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.github/instructions/ra.instructions.md" ]
  [ ! -f "$TEST_OUT/.github/instructions/rb.instructions.md" ]
}
