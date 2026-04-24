#!/usr/bin/env bats
# MCP — agent frontmatter translation across tools.

load test_helper

setup() {
  TEST_SRC="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_mcp_fm_src.XXXXXX")"
  TEST_OUT="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_mcp_fm_out.XXXXXX")"
  mkdir -p "$TEST_SRC/agents"
  cat > "$TEST_SRC/agents/aside.md" <<'MD'
---
name: aside
description: Side question agent.
mcp-servers: "context7, memory"
---

Body.
MD
  cat > "$TEST_SRC/agents/plain.md" <<'MD'
---
name: plain
description: No MCP.
---

Plain body.
MD
}

teardown() {
  [[ -n "${TEST_SRC:-}" && -d "$TEST_SRC" ]] && rm -rf "$TEST_SRC"
  [[ -n "${TEST_OUT:-}" && -d "$TEST_OUT" ]] && rm -rf "$TEST_OUT"
}

@test "cursor sync-agents: strips mcp-servers from frontmatter" {
  run bash "${REPO_ROOT}/scripts/cursor/sync-agents.sh" -i "$TEST_SRC/agents" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  ! grep -q '^mcp-servers:' "$TEST_OUT/.cursor/agents/aside.md"
  ! grep -q '^mcpServers:' "$TEST_OUT/.cursor/agents/aside.md"
  ! grep -q '^tools:'       "$TEST_OUT/.cursor/agents/aside.md"
}

@test "claude sync-agents: rewrites mcp-servers to mcpServers flow list" {
  run bash "${REPO_ROOT}/scripts/claude/sync-agents.sh" -i "$TEST_SRC/agents" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  ! grep -q '^mcp-servers:' "$TEST_OUT/.claude/agents/aside.md"
  grep -q '^mcpServers: \[context7, memory\]$' "$TEST_OUT/.claude/agents/aside.md"
  # Plain agent untouched.
  ! grep -q '^mcpServers:' "$TEST_OUT/.claude/agents/plain.md"
}

@test "copilot sync-agents: rewrites mcp-servers to tools list with /* suffix" {
  run bash "${REPO_ROOT}/scripts/copilot/sync-agents.sh" -i "$TEST_SRC/agents" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  ! grep -q '^mcp-servers:' "$TEST_OUT/.github/agents/aside.md"
  grep -q '^tools: \["context7/\*", "memory/\*"\]$' "$TEST_OUT/.github/agents/aside.md"
}

@test "junie sync-agents: strips mcp-servers from frontmatter" {
  run bash "${REPO_ROOT}/scripts/junie/sync-agents.sh" -i "$TEST_SRC/agents" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  ! grep -q '^mcp-servers:' "$TEST_OUT/.junie/agents/aside.md"
  ! grep -q '^tools:'       "$TEST_OUT/.junie/agents/aside.md"
}

@test "copilot sync-agents: error when both mcp-servers and tools are present" {
  cat > "$TEST_SRC/agents/conflict.md" <<'MD'
---
name: conflict
description: Conflicting agent.
mcp-servers: "context7"
tools: ["foo/*"]
---

Body.
MD
  run bash "${REPO_ROOT}/scripts/copilot/sync-agents.sh" -i "$TEST_SRC/agents" -o "$TEST_OUT" --items conflict
  [ "$status" -ne 0 ]
  [[ "$output" == *"both 'mcp-servers' and 'tools'"* ]]
}
