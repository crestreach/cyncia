#!/usr/bin/env bats
# MCP sync — basic per-tool translation tests.

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

@test "cursor sync-mcp: writes .cursor/mcp.json with mcpServers and \${env:NAME}" {
  run bash "${REPO_ROOT}/scripts/cursor/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.cursor/mcp.json" ]
  # Top-level key is mcpServers
  [ "$(jq -r 'keys[]' "$TEST_OUT/.cursor/mcp.json")" = "mcpServers" ]
  # Both servers present
  [ "$(jq -r '.mcpServers | keys | sort | join(",")' "$TEST_OUT/.cursor/mcp.json")" = "context7,httpbin" ]
  # Optional secret -> ${env:NAME}
  [ "$(jq -r '.mcpServers.context7.env.CONTEXT7_API_KEY' "$TEST_OUT/.cursor/mcp.json")" = '${env:CONTEXT7_API_KEY}' ]
  # Required secret -> ${env:NAME}
  [ "$(jq -r '.mcpServers.httpbin.headers.Authorization' "$TEST_OUT/.cursor/mcp.json")" = 'Bearer ${env:HTTPBIN_TOKEN}' ]
}

@test "claude sync-mcp: writes .mcp.json with required \${NAME} and optional \${NAME:-}" {
  run bash "${REPO_ROOT}/scripts/claude/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.mcp.json" ]
  [ "$(jq -r 'keys[]' "$TEST_OUT/.mcp.json")" = "mcpServers" ]
  # Optional -> ${NAME:-}
  [ "$(jq -r '.mcpServers.context7.env.CONTEXT7_API_KEY' "$TEST_OUT/.mcp.json")" = '${CONTEXT7_API_KEY:-}' ]
  # Required -> ${NAME}
  [ "$(jq -r '.mcpServers.httpbin.headers.Authorization' "$TEST_OUT/.mcp.json")" = 'Bearer ${HTTPBIN_TOKEN}' ]
}

@test "vscode sync-mcp: writes .vscode/mcp.json with servers + inputs[]" {
  run bash "${REPO_ROOT}/scripts/vscode/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.vscode/mcp.json" ]
  # Top-level keys: servers + inputs
  [ "$(jq -r 'keys | sort | join(",")' "$TEST_OUT/.vscode/mcp.json")" = "inputs,servers" ]
  # Token rewrite
  [ "$(jq -r '.servers.context7.env.CONTEXT7_API_KEY' "$TEST_OUT/.vscode/mcp.json")" = '${input:CONTEXT7_API_KEY}' ]
  [ "$(jq -r '.servers.httpbin.headers.Authorization' "$TEST_OUT/.vscode/mcp.json")" = 'Bearer ${input:HTTPBIN_TOKEN}' ]
  # inputs[] entries
  [ "$(jq -r '.inputs | length' "$TEST_OUT/.vscode/mcp.json")" = "2" ]
  # Optional input has default ""
  [ "$(jq -r '.inputs[] | select(.id=="CONTEXT7_API_KEY") | .default' "$TEST_OUT/.vscode/mcp.json")" = "" ]
  [ "$(jq -r '.inputs[] | select(.id=="CONTEXT7_API_KEY") | has("default")' "$TEST_OUT/.vscode/mcp.json")" = "true" ]
  # Required input has no default key
  [ "$(jq -r '.inputs[] | select(.id=="HTTPBIN_TOKEN") | has("default")' "$TEST_OUT/.vscode/mcp.json")" = "false" ]
  # Both marked password
  [ "$(jq -r '[.inputs[] | .password] | unique | join(",")' "$TEST_OUT/.vscode/mcp.json")" = "true" ]
}

@test "junie sync-mcp: prints stdout snippet, writes nothing under .junie" {
  run bash "${REPO_ROOT}/scripts/junie/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"mcpServers"* ]]
  [[ "$output" == *"context7"* ]]
  [[ "$output" == *"httpbin"* ]]
  [ ! -d "$TEST_OUT/.junie" ] || [ -z "$(find "$TEST_OUT/.junie" -type f 2>/dev/null)" ]
}

@test "codex sync-mcp: writes .codex/config.toml with Codex MCP tables" {
  run bash "${REPO_ROOT}/scripts/codex/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.codex/config.toml" ]
  grep -q '^\[mcp_servers\."context7"\]$' "$TEST_OUT/.codex/config.toml"
  grep -q '^command = "npx"$' "$TEST_OUT/.codex/config.toml"
  grep -q '^env_vars = \["CONTEXT7_API_KEY"\]$' "$TEST_OUT/.codex/config.toml"
  grep -q '^\[mcp_servers\."httpbin"\]$' "$TEST_OUT/.codex/config.toml"
  grep -q '^url = "https://httpbin.example/api"$' "$TEST_OUT/.codex/config.toml"
  grep -q '^bearer_token_env_var = "HTTPBIN_TOKEN"$' "$TEST_OUT/.codex/config.toml"
}

@test "codex sync-mcp: merges only mcp_servers into existing config.toml" {
  mkdir -p "$TEST_OUT/.codex"
  cat > "$TEST_OUT/.codex/config.toml" <<'TOML'
model = "gpt-5"

[mcp_servers."keep"]
command = "keep-server"

[mcp_servers."context7"]
command = "old-server"
TOML

  run bash "${REPO_ROOT}/scripts/codex/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT" --items context7
  [ "$status" -eq 0 ]
  grep -q '^model = "gpt-5"$' "$TEST_OUT/.codex/config.toml"
  grep -q '^\[mcp_servers\."keep"\]$' "$TEST_OUT/.codex/config.toml"
  grep -q '^command = "keep-server"$' "$TEST_OUT/.codex/config.toml"
  grep -q '^\[mcp_servers\."context7"\]$' "$TEST_OUT/.codex/config.toml"
  grep -q '^command = "npx"$' "$TEST_OUT/.codex/config.toml"
  ! grep -q 'old-server' "$TEST_OUT/.codex/config.toml"

  run bash "${REPO_ROOT}/scripts/codex/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT" --items context7 --clean
  [ "$status" -eq 0 ]
  grep -q '^model = "gpt-5"$' "$TEST_OUT/.codex/config.toml"
  ! grep -q '^\[mcp_servers\."keep"\]$' "$TEST_OUT/.codex/config.toml"
  grep -q '^\[mcp_servers\."context7"\]$' "$TEST_OUT/.codex/config.toml"
}

@test "codex sync-mcp: codex-sync-mcp false leaves config.toml untouched" {
  mkdir -p "$TEST_OUT/.codex"
  cat > "$TEST_OUT/.codex/config.toml" <<'TOML'
model = "gpt-5"

[mcp_servers."existing"]
command = "existing-server"
TOML
  cp "$TEST_OUT/.codex/config.toml" "$TEST_OUT/config.before"
  conf="$TEST_OUT/cyncia.conf"
  echo 'codex-sync-mcp: false' > "$conf"
  export CYNCIA_CONF="$conf"
  run bash "${REPO_ROOT}/scripts/codex/sync-mcp.sh" -i "$TEST_SRC/mcp-servers" -o "$TEST_OUT" --clean
  unset CYNCIA_CONF
  [ "$status" -eq 0 ]
  diff -u "$TEST_OUT/config.before" "$TEST_OUT/.codex/config.toml"
}
