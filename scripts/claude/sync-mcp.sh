#!/usr/bin/env bash
# Sync MCP servers from <mcp_servers_dir>/*.json to <output_root>/.mcp.json.
#
# Translation of generic tokens:
#   ${secret:NAME}           -> ${NAME}
#   ${secret:NAME?optional}  -> ${NAME:-}
#
# Usage:
#   sync-mcp.sh -i <mcp_servers_dir> -o <output_root> [--items name1,name2] [--clean] [--help]
#
#   --items  Comma-separated subset of server basenames.
#   --clean  Overwrite .mcp.json. If the filtered set is empty while --clean
#            is set, the target file is removed.
#
# Examples (project root = output; input = examples/mcp-servers):
#   sync-mcp.sh -i "$PWD/examples/mcp-servers" -o "$PWD"

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)"
source "$COMMON_DIR/common.sh"
source "$COMMON_DIR/mcp.sh"

parse_io_args "$@"
INPUT_DIR="$(to_abs_dir "$INPUT")"
OUTPUT_DIR="$(to_abs_dir "$OUTPUT")"
require_jq

DST="$OUTPUT_DIR/.mcp.json"

PAIRS="$(mcp_list_server_files "$INPUT_DIR")"
if [[ -z "$PAIRS" ]]; then
  if [[ "$CLEAN" == "true" && -f "$DST" ]]; then
    rm -f "$DST"
    echo "claude mcp: cleaned $DST (no matching servers)"
  else
    echo "claude mcp: no servers selected; skip"
  fi
  exit 0
fi

mcp_assemble_servers 'mcpServers' mcp_translate_body_claude "$INPUT_DIR" > "$DST"
echo "claude mcp -> $DST"
