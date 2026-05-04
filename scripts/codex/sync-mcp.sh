#!/usr/bin/env bash
# Sync MCP servers from <mcp_servers_dir>/*.json to <output_root>/.codex/config.toml.
#
# Codex stores MCP servers in config.toml as [mcp_servers.<name>] tables.
# This script writes a generated project-scoped .codex/config.toml containing
# only MCP server configuration.
#
# Secret token handling:
#   env value "${secret:NAME}" with key NAME -> env_vars = ["NAME"]
#   Authorization header "Bearer ${secret:NAME}" -> bearer_token_env_var = "NAME"
#   header value "${secret:NAME}" -> env_http_headers.<header> = "NAME"
#
# Usage:
#   sync-mcp.sh -i <mcp_servers_dir> -o <output_root> [--items name1,name2] [--clean] [--help]
#
#   --items  Comma-separated subset of server basenames.
#   --clean  Overwrite .codex/config.toml. If the filtered set is empty while
#            --clean is set, the target file is removed.

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)"
source "$COMMON_DIR/common.sh"
source "$COMMON_DIR/mcp.sh"

parse_io_args "$@"
INPUT_DIR="$(to_abs_dir "$INPUT")"
OUTPUT_DIR="$(to_abs_dir "$OUTPUT")"
require_jq

DST="$OUTPUT_DIR/.codex/config.toml"
mkdir -p "$(dirname "$DST")"

PAIRS="$(mcp_list_server_files "$INPUT_DIR")"
if [[ -z "$PAIRS" ]]; then
  if [[ "$CLEAN" == "true" && -f "$DST" ]]; then
    rm -f "$DST"
    echo "codex mcp: cleaned $DST (no matching servers)"
  else
    echo "codex mcp: no servers selected; skip"
  fi
  exit 0
fi

mcp_emit_codex_toml "$INPUT_DIR" > "$DST"
echo "codex mcp -> $DST"
