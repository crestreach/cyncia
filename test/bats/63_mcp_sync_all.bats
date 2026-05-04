#!/usr/bin/env bats
# MCP sync — sync-all integration.

load test_helper

FIXTURE_MCP="${REPO_ROOT}/test/fixtures/mcp"

setup() {
  TEST_SRC="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_mcp_src.XXXXXX")"
  TEST_OUT="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_mcp_out.XXXXXX")"
  # Start from the two-skills fixture (provides AGENTS.md and friends).
  cp -R "${FIXTURE_TWO}/." "$TEST_SRC/"
  # Add MCP servers from the MCP fixture.
  mkdir -p "$TEST_SRC/mcp-servers"
  cp "${FIXTURE_MCP}/mcp-servers/"*.json "$TEST_SRC/mcp-servers/"
}

teardown() {
  [[ -n "${TEST_SRC:-}" && -d "$TEST_SRC" ]] && rm -rf "$TEST_SRC"
  [[ -n "${TEST_OUT:-}" && -d "$TEST_OUT" ]] && rm -rf "$TEST_OUT"
}

@test "sync-all: writes MCP config for cursor, claude, vscode, and codex when mcp-servers/ present" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.cursor/mcp.json" ]
  [ -f "$TEST_OUT/.mcp.json" ]
  [ -f "$TEST_OUT/.vscode/mcp.json" ]
  [ -f "$TEST_OUT/.codex/config.toml" ]
  # Junie does not write a file.
  [ ! -f "$TEST_OUT/.junie/mcp.json" ]
  # Snippet should still be printed to stdout.
  [[ "$output" == *"junie mcp:"* ]]
}

@test "sync-all: no MCP step when mcp-servers/ absent" {
  rm -rf "$TEST_SRC/mcp-servers"
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT"
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_OUT/.cursor/mcp.json" ]
  [ ! -f "$TEST_OUT/.mcp.json" ]
  [ ! -f "$TEST_OUT/.vscode/mcp.json" ]
  [ ! -f "$TEST_OUT/.codex/config.toml" ]
}

@test "sync-all --tools cursor: only cursor mcp.json produced" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools cursor
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.cursor/mcp.json" ]
  [ ! -f "$TEST_OUT/.mcp.json" ]
  [ ! -f "$TEST_OUT/.vscode/mcp.json" ]
  [ ! -f "$TEST_OUT/.codex/config.toml" ]
}

@test "sync-all --tools codex: only codex MCP config produced" {
  run bash "$SYNC_ALL_SH" -i "$TEST_SRC" -o "$TEST_OUT" --tools codex
  [ "$status" -eq 0 ]
  [ -f "$TEST_OUT/.codex/config.toml" ]
  [ ! -f "$TEST_OUT/.cursor/mcp.json" ]
  [ ! -f "$TEST_OUT/.mcp.json" ]
  [ ! -f "$TEST_OUT/.vscode/mcp.json" ]
}
