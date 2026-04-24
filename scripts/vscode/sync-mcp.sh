#!/usr/bin/env bash
# Sync MCP servers from <mcp_servers_dir>/*.json to <output_root>/.vscode/mcp.json.
#
# This is VS Code's own MCP configuration file (see
# https://code.visualstudio.com/docs/copilot/chat/mcp-servers). GitHub Copilot
# Chat in VS Code reads the same file, but the format belongs to VS Code, not
# to Copilot.
#
# Translation of generic tokens:
#   ${secret:NAME}           -> ${input:NAME}  (+ inputs[] entry, password: true)
#   ${secret:NAME?optional}  -> ${input:NAME}  (+ inputs[] entry, password: true,
#                                                default: "")
#
# Usage:
#   sync-mcp.sh -i <mcp_servers_dir> -o <output_root> [--items name1,name2] [--clean] [--help]
#
#   --items  Comma-separated subset of server basenames.
#   --clean  Overwrite .vscode/mcp.json. If the filtered set is empty while
#            --clean is set, the target file is removed.
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

DST="$OUTPUT_DIR/.vscode/mcp.json"
mkdir -p "$(dirname "$DST")"

PAIRS="$(mcp_list_server_files "$INPUT_DIR")"
if [[ -z "$PAIRS" ]]; then
  if [[ "$CLEAN" == "true" && -f "$DST" ]]; then
    rm -f "$DST"
    echo "vscode mcp: cleaned $DST (no matching servers)"
  else
    echo "vscode mcp: no servers selected; skip"
  fi
  exit 0
fi

SERVERS="$(mcp_assemble_servers 'servers' mcp_translate_body_vscode "$INPUT_DIR")"
INPUTS="$(mcp_collect_inputs_vscode "$INPUT_DIR")"

if [[ "$(jq 'length' <<< "$INPUTS")" -gt 0 ]]; then
  jq -n --argjson s "$SERVERS" --argjson i "$INPUTS" '$s + {inputs: $i}' > "$DST"
else
  echo "$SERVERS" > "$DST"
fi
echo "vscode mcp -> $DST"
