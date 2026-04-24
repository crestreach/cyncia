#!/usr/bin/env bash
# Print a paste-ready "mcpServers" JSON snippet for JetBrains AI Assistant / Junie.
#
# Junie has no documented project-local MCP config file, so this script writes
# NO files under .junie/. Instead it prints a JSON document to stdout that the
# user can paste into:
#
#   Settings | Tools | AI Assistant | Model Context Protocol (MCP) | Add server
#
# Translation of generic tokens: the source form is preserved verbatim (Junie
# does not document a shared interpolation syntax; users must edit secrets in
# place or rely on their shell environment depending on transport).
#
# Usage:
#   sync-mcp.sh -i <mcp_servers_dir> -o <output_root> [--items name1,name2] [--clean] [--help]
#
#   -o/--output  Ignored (kept for flag parity with the other tools).
#   --items      Comma-separated subset of server basenames.
#   --clean      Ignored (no file is written).

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)"
source "$COMMON_DIR/common.sh"
source "$COMMON_DIR/mcp.sh"

parse_io_args "$@"
INPUT_DIR="$(to_abs_dir "$INPUT")"
# OUTPUT is accepted but unused; validate it's a directory for flag parity.
to_abs_dir "$OUTPUT" >/dev/null
require_jq

PAIRS="$(mcp_list_server_files "$INPUT_DIR")"
if [[ -z "$PAIRS" ]]; then
  echo "junie mcp: no servers selected; nothing to print"
  exit 0
fi

# Pass through unchanged (no token translation).
mcp_passthrough() { cat "$1"; }

SNIPPET="$(mcp_assemble_servers 'mcpServers' mcp_passthrough "$INPUT_DIR")"
echo "junie mcp: paste the following into Settings | Tools | AI Assistant | Model Context Protocol (MCP):"
echo "$SNIPPET"
