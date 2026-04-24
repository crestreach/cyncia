#!/usr/bin/env bats
# Additional coverage to align with Pester scenarios.

load test_helper

@test "sync-all --clean: removing agent from source drops stale agent file" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.cursor/agents/one.md" ]
  rm -f "$TEST_SRC/agents/one.md"
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor --clean
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_OUT/.cursor/agents/one.md" ]
}

@test "skill frontmatter translation: cursor strips applies-to; claude renames to paths" {
  # Add applies-to inside SKILL.md frontmatter using awk (no python3 required)
  skill_file="$TEST_SRC/skills/alpha/SKILL.md"
  if grep -q 'description: First test skill.' "$skill_file" && ! grep -q 'applies-to:' "$skill_file"; then
    awk '/^description: First test skill\.$/ { print; print "applies-to: \"**/*.java\""; next } { print }' \
      "$skill_file" > "$skill_file.tmp" && mv "$skill_file.tmp" "$skill_file"
  fi

  # Cursor strips
  run bash "${REPO_ROOT}/scripts/cursor/sync-skills.sh" -i "$TEST_SRC/skills" -o "$TEST_OUT" --items alpha
  [ "$status" -eq 0 ]
  ! grep -q '^applies-to:' "$TEST_OUT/.cursor/skills/alpha/SKILL.md"

  # Claude renames
  run bash "${REPO_ROOT}/scripts/claude/sync-skills.sh" -i "$TEST_SRC/skills" -o "$TEST_OUT" --items alpha
  [ "$status" -eq 0 ]
  grep -q '^paths:' "$TEST_OUT/.claude/skills/alpha/SKILL.md"
  ! grep -q '^applies-to:' "$TEST_OUT/.claude/skills/alpha/SKILL.md"
}

@test "copilot sync-rules --clean removes stale instruction file" {
  mkdir -p "$TEST_OUT/.github/instructions"
  echo "stale" > "$TEST_OUT/.github/instructions/stale.instructions.md"
  run bash "${REPO_ROOT}/scripts/copilot/sync-rules.sh" -i "$TEST_SRC/rules" -o "$TEST_OUT" --items ra --clean
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_OUT/.github/instructions/stale.instructions.md" ]
  [ -f "$TEST_OUT/.github/instructions/ra.instructions.md" ]
}

@test "copilot/junie/claude agent-guidelines --clean removes tool output files" {
  # Generate once
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools claude,copilot,junie
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/CLAUDE.md" ]
  [ -f "$TEST_OUT/.github/copilot-instructions.md" ]
  [ -f "$TEST_OUT/.junie/AGENTS.md" ]

  # Re-run just agent-guidelines with --clean and verify it can remove+recreate
  run bash "${REPO_ROOT}/scripts/claude/sync-agent-guidelines.sh" -i "$TEST_SRC" -o "$TEST_OUT" --clean
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/CLAUDE.md" ]

  run bash "${REPO_ROOT}/scripts/copilot/sync-agent-guidelines.sh" -i "$TEST_SRC" -o "$TEST_OUT" --clean
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.github/copilot-instructions.md" ]

  run bash "${REPO_ROOT}/scripts/junie/sync-agent-guidelines.sh" -i "$TEST_SRC" -o "$TEST_OUT" --clean
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.junie/AGENTS.md" ]
  # Junie AGENTS should include rules section (merged like CLAUDE.md)
  grep -Fq '## Project rules' "$TEST_OUT/.junie/AGENTS.md"
  grep -Fq '### `ra.md`' "$TEST_OUT/.junie/AGENTS.md"
}

@test "cursor agent-guidelines --clean with same -i and -o does not delete AGENTS.md" {
  GSH="${REPO_ROOT}/scripts/cursor/sync-agent-guidelines.sh"
  SAME="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_same.XXXXXX")"
  cp "$TEST_SRC/AGENTS.md" "$SAME/AGENTS.md"
  run bash "$GSH" -i "$SAME" -o "$SAME" --clean
  [ "$status" -eq 0 ]
  [ -f "$SAME/AGENTS.md" ]
  rm -rf "$SAME"
}

