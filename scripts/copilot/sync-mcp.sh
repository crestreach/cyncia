#!/usr/bin/env bash
# No-op: MCP server configuration for VS Code (including Copilot Chat in VS
# Code) lives in .vscode/mcp.json, which is a VS Code format, not a Copilot
# format. It is handled by scripts/vscode/sync-mcp.sh.
#
# This file is kept so sync-all can still iterate the copilot tool uniformly
# and so existing callers of scripts/copilot/sync-mcp.sh don't break.
#
# Usage:
#   sync-mcp.sh -i <mcp_servers_dir> -o <output_root> [--items ...] [--clean] [--help]

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
echo "copilot mcp: nothing to do (MCP config for Copilot Chat in VS Code is written by scripts/vscode/sync-mcp.sh -> .vscode/mcp.json)"
