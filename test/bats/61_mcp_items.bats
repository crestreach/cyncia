#!/usr/bin/env bats
# MCP sync — --items subset filtering.

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

@test "cursor sync-mcp --items context7: only context7 in mcpServers" {
  run bash "${REPO_ROOT}/scripts/cursor/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT" --items context7
  [ "$status" -eq 0 ]
  [ "$(jq -r '.mcpServers | keys | join(",")' "$TEST_OUT/.cursor/mcp.json")" = "context7" ]
}

@test "vscode sync-mcp --items httpbin: only httpbin and only its input" {
  run bash "${REPO_ROOT}/scripts/vscode/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT" --items httpbin
  [ "$status" -eq 0 ]
  [ "$(jq -r '.servers | keys | join(",")' "$TEST_OUT/.vscode/mcp.json")" = "httpbin" ]
  [ "$(jq -r '.inputs | length' "$TEST_OUT/.vscode/mcp.json")" = "1" ]
  [ "$(jq -r '.inputs[0].id' "$TEST_OUT/.vscode/mcp.json")" = "HTTPBIN_TOKEN" ]
}

@test "claude sync-mcp --items unknown: skip warning, no file changes" {
  # Pre-existing file should remain untouched when no servers selected and --clean is off.
  mkdir -p "$TEST_OUT"
  echo '{"keep":true}' > "$TEST_OUT/.mcp.json"
  run bash "${REPO_ROOT}/scripts/claude/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT" --items doesnotexist
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip: doesnotexist"* ]] || [[ "$output" == *"no servers selected"* ]]
  [ -f "$TEST_OUT/.mcp.json" ]
  [ "$(jq -r '.keep' "$TEST_OUT/.mcp.json")" = "true" ]
}
