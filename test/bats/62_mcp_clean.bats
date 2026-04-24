#!/usr/bin/env bats
# MCP sync — --clean and overwrite semantics.

load test_helper

FIXTURE_MCP="${REPO_ROOT}/test/fixtures/mcp"

setup() {
  TEST_SRC="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_mcp_src.XXXXXX")"
  TEST_OUT="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_mcp_out.XXXXXX")"
  cp -R "${FIXTURE_MCP}/." "$TEST_SRC/"
}

teardown() {
  [[ -n "${TEST_SRC:-}" && -d "$TEST_SRC" ]] && rm -rf "$TEST_SRC"
  [[ -n "${TEST_OUT:-}" && -d "$TEST_OUT" ]] && rm -rf "$TEST_OUT"
}

@test "cursor sync-mcp: rerun replaces file (not merged)" {
  # First run with both servers.
  run bash "${REPO_ROOT}/scripts/cursor/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.mcpServers | length' "$TEST_OUT/.cursor/mcp.json")" = "2" ]
  # Second run with only context7 — file must shrink.
  run bash "${REPO_ROOT}/scripts/cursor/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT" --items context7
  [ "$status" -eq 0 ]
  [ "$(jq -r '.mcpServers | length' "$TEST_OUT/.cursor/mcp.json")" = "1" ]
  [ "$(jq -r '.mcpServers | keys | join(",")' "$TEST_OUT/.cursor/mcp.json")" = "context7" ]
}

@test "vscode sync-mcp --clean with empty filter removes target" {
  run bash "${REPO_ROOT}/scripts/vscode/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.vscode/mcp.json" ]
  # Remove all source files, then re-run with --clean.
  rm -f "$TEST_SRC/mcp-servers/"*.json
  run bash "${REPO_ROOT}/scripts/vscode/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT" --clean
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_OUT/.vscode/mcp.json" ]
}

@test "claude sync-mcp --clean with empty filter removes target" {
  run bash "${REPO_ROOT}/scripts/claude/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.mcp.json" ]
  rm -f "$TEST_SRC/mcp-servers/"*.json
  run bash "${REPO_ROOT}/scripts/claude/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT" --clean
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_OUT/.mcp.json" ]
}
