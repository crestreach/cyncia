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

@test "sync-all: all tool dirs are created" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [ -d "$TEST_OUT/.cursor" ]
  [ -d "$TEST_OUT/.claude" ]
  [ -d "$TEST_OUT/.github" ]
  [ -d "$TEST_OUT/.junie" ]
  [ -d "$TEST_OUT/.codex" ]
  [ -d "$TEST_OUT/.agents" ]
  [ -f "$TEST_OUT/CLAUDE.md" ]
  [ -f "$TEST_OUT/.github/copilot-instructions.md" ]
  [ -f "$TEST_OUT/.github/agents/one.agent.md" ]
  [ ! -f "$TEST_OUT/.github/agents/one.md" ]
  [ -f "$TEST_OUT/.junie/AGENTS.md" ]
  [ -f "$TEST_OUT/AGENTS.override.md" ]
  [ -f "$TEST_OUT/.codex/agents/one.toml" ]
  [ -f "$TEST_OUT/.agents/skills/alpha/SKILL.md" ]
}

@test "sync-all: codex only produces Codex outputs" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools codex
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/AGENTS.md" ]
  [ -f "$TEST_OUT/AGENTS.override.md" ]
  grep -q '^## Project rules' "$TEST_OUT/AGENTS.override.md"
  grep -q '^#### Rule A' "$TEST_OUT/AGENTS.override.md"
  [ -f "$TEST_OUT/.codex/agents/one.toml" ]
  [ -f "$TEST_OUT/.agents/skills/alpha/SKILL.md" ]
  [ ! -d "$TEST_OUT/.cursor" ]
  [ ! -d "$TEST_OUT/.claude" ]
  [ ! -d "$TEST_OUT/.github" ]
}

@test "sync-all: embedded rule headings are normalized below rule wrapper" {
  cat > "$TEST_SRC/rules/ra.md" <<'EOF'
---
description: Nested headings
---

## Top

### Child

#### Grandchild

```sh
# Not a heading
```
EOF

  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools claude,codex,junie
  [ "$status" -eq 0 ]
  for generated in \
    "$TEST_OUT/CLAUDE.md" \
    "$TEST_OUT/AGENTS.override.md" \
    "$TEST_OUT/.junie/AGENTS.md"
  do
    grep -q '^### `ra.md`' "$generated"
    grep -q '^#### Top$' "$generated"
    grep -q '^##### Child$' "$generated"
    grep -q '^###### Grandchild$' "$generated"
    grep -q '^# Not a heading$' "$generated"
    ! grep -q '^## Top$' "$generated"
  done
}

@test "sync-all: default-tools from cyncia.conf controls omitted --tools" {
  conf="$TEST_OUT/cyncia.conf"
  echo 'default-tools: codex' > "$conf"
  export CYNCIA_CONF="$conf"
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT"
  unset CYNCIA_CONF
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.codex/agents/one.toml" ]
  [ -f "$TEST_OUT/.agents/skills/alpha/SKILL.md" ]
  [ ! -d "$TEST_OUT/.cursor" ]
  [ ! -d "$TEST_OUT/.claude" ]
  [ ! -d "$TEST_OUT/.github" ]
}

@test "sync-all: codex-rules-mode ignore skips AGENTS.override.md" {
  conf="$TEST_OUT/cyncia.conf"
  echo 'codex-rules-mode: ignore' > "$conf"
  export CYNCIA_CONF="$conf"
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools codex
  unset CYNCIA_CONF
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/AGENTS.md" ]
  [ ! -f "$TEST_OUT/AGENTS.override.md" ]
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
