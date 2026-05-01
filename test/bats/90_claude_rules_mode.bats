#!/usr/bin/env bats
# Tests for the claude_rules_mode switch read from cyncia.conf.
#
# scripts/claude/sync-{agent-guidelines,rules}.sh look at:
#   1. $CYNCIA_CONF if set, else
#   2. .cyncia/cyncia.conf relative to the installed script location
#      (resolved as the parent of common.sh's scripts directory; see
#      read_cyncia_conf in scripts/common/common.sh).
#
# The default mode is "claude-md" (current behavior, rules merged into
# CLAUDE.md). Mode "rule-files" emits one file per rule under
# <output_root>/.claude/rules/<name>.md and replaces the merged section in
# CLAUDE.md with `@`-import lines.

load test_helper

CLAUDE_GL_SH="${REPO_ROOT}/scripts/claude/sync-agent-guidelines.sh"
CLAUDE_RULES_SH="${REPO_ROOT}/scripts/claude/sync-rules.sh"

@test "claude rules: default mode (no cyncia.conf) merges bodies into CLAUDE.md" {
  unset CYNCIA_CONF
  run bash "$CLAUDE_GL_SH" -i "$TEST_SRC" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/CLAUDE.md" ]
  # Body of ra.md is inlined.
  grep -q '### `ra.md`' "$TEST_OUT/CLAUDE.md"
  grep -q '# Rule A' "$TEST_OUT/CLAUDE.md"
  # No @-imports in default mode.
  ! grep -q '^@\.claude/rules/' "$TEST_OUT/CLAUDE.md"

  run bash "$CLAUDE_RULES_SH" -i "$TEST_SRC/rules" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped"* ]]
  [ ! -d "$TEST_OUT/.claude/rules" ]
}

@test "claude rules: rule-files mode emits per-rule files and @-imports" {
  conf="$TEST_OUT/cyncia.conf"
  echo "claude_rules_mode: rule-files" > "$conf"
  export CYNCIA_CONF="$conf"

  run bash "$CLAUDE_GL_SH" -i "$TEST_SRC" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/CLAUDE.md" ]
  grep -q '^@\.claude/rules/ra\.md$' "$TEST_OUT/CLAUDE.md"
  grep -q '^@\.claude/rules/rb\.md$' "$TEST_OUT/CLAUDE.md"
  # Bodies are NOT inlined in rule-files mode.
  ! grep -q '### `ra.md`' "$TEST_OUT/CLAUDE.md"
  ! grep -q '# Rule A' "$TEST_OUT/CLAUDE.md"

  run bash "$CLAUDE_RULES_SH" -i "$TEST_SRC/rules" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.claude/rules/ra.md" ]
  [ -f "$TEST_OUT/.claude/rules/rb.md" ]
  # Per-rule file has the heading, the description (italic), and body, but
  # no YAML frontmatter.
  ! grep -q '^---$' "$TEST_OUT/.claude/rules/ra.md"
  grep -q '^# `ra.md`' "$TEST_OUT/.claude/rules/ra.md"
  grep -q '^_Rule A_' "$TEST_OUT/.claude/rules/ra.md"
  grep -q '# Rule A' "$TEST_OUT/.claude/rules/ra.md"
}

@test "claude rules: rule-files mode with --clean removes stale per-rule files" {
  conf="$TEST_OUT/cyncia.conf"
  echo "claude_rules_mode: rule-files" > "$conf"
  export CYNCIA_CONF="$conf"

  mkdir -p "$TEST_OUT/.claude/rules"
  echo "stale" > "$TEST_OUT/.claude/rules/legacy.md"

  run bash "$CLAUDE_RULES_SH" -i "$TEST_SRC/rules" -o "$TEST_OUT" --clean
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_OUT/.claude/rules/legacy.md" ]
  [ -f "$TEST_OUT/.claude/rules/ra.md" ]
}

@test "claude rules: invalid mode falls back to claude-md with warning" {
  conf="$TEST_OUT/cyncia.conf"
  echo "claude_rules_mode: bogus" > "$conf"
  export CYNCIA_CONF="$conf"

  run bash "$CLAUDE_GL_SH" -i "$TEST_SRC" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unknown claude_rules_mode='bogus'"* ]]
  grep -q '### `ra.md`' "$TEST_OUT/CLAUDE.md"
  ! grep -q '^@\.claude/rules/' "$TEST_OUT/CLAUDE.md"
}

@test "sync-all: rule-files mode produces both CLAUDE.md @-imports and per-rule files" {
  conf="$TEST_OUT/cyncia.conf"
  echo "claude_rules_mode: rule-files" > "$conf"
  export CYNCIA_CONF="$conf"

  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools claude
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/CLAUDE.md" ]
  grep -q '^@\.claude/rules/ra\.md$' "$TEST_OUT/CLAUDE.md"
  [ -f "$TEST_OUT/.claude/rules/ra.md" ]
  [ -f "$TEST_OUT/.claude/rules/rb.md" ]
}
