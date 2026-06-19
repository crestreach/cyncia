#!/usr/bin/env bats
# Regression test for the mawk regex panic in heading_level().
#
# scripts/common/common.sh's heading_level() used a bounded interval
# (/^#{1,6}([ \t]|$)/) that mawk 1.3.4's regex compiler refuses with
# "REcompile() - panic: values still on machine stack". That aborted the
# guideline+rules merge mid-write, truncating CLAUDE.md / .junie/AGENTS.md.
#
# These tests force `awk` to mawk via a PATH shim and confirm the merge runs
# to completion (rule bodies inlined, no panic). They skip when mawk is not
# installed.

load test_helper

CLAUDE_GL_SH="${REPO_ROOT}/scripts/claude/sync-agent-guidelines.sh"

setup_mawk_shim() {
  if ! command -v mawk >/dev/null 2>&1; then
    skip "mawk not installed"
  fi
  SHIM_DIR="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_shim.XXXXXX")"
  ln -s "$(command -v mawk)" "$SHIM_DIR/awk"
  export PATH="$SHIM_DIR:$PATH"
}

@test "mawk: claude agent-guidelines merge completes without REcompile panic" {
  setup_mawk_shim
  unset CYNCIA_CONF
  run bash "$CLAUDE_GL_SH" -i "$TEST_SRC" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"panic"* ]]
  [ -f "$TEST_OUT/CLAUDE.md" ]
  # Rule bodies are fully merged (not truncated) and ATX headings preserved.
  grep -q '### `ra.md`' "$TEST_OUT/CLAUDE.md"
  grep -q '^#### Rule A' "$TEST_OUT/CLAUDE.md"
  grep -q '### `rb.md`' "$TEST_OUT/CLAUDE.md"
  grep -q '^#### Rule B' "$TEST_OUT/CLAUDE.md"
}
