#!/usr/bin/env bash
# Sync MCP servers from <mcp_servers_dir>/*.json to <output_root>/.codex/config.toml.
#
# Codex stores MCP servers in config.toml as [mcp_servers.<name>] tables.
# This script updates the project-scoped .codex/config.toml mcp_servers tables
# without rewriting unrelated Codex config.
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
#   --clean  Replace all existing mcp_servers tables with the selected source
#            servers. Without --clean, only selected/generated server tables are
#            added or updated; unrelated existing mcp_servers are preserved.

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)"
source "$COMMON_DIR/common.sh"
source "$COMMON_DIR/mcp.sh"

parse_io_args "$@"
INPUT_DIR="$(to_abs_dir "$INPUT")"
OUTPUT_DIR="$(to_abs_dir "$OUTPUT")"
require_jq

codex_mcp_enabled() {
  local value
  value="$(read_cyncia_conf codex-sync-mcp true | tr '[:upper:]' '[:lower:]')"
  case "$value" in
    true|yes|y|1|on) return 0 ;;
    false|no|n|0|off) return 1 ;;
    *)
      echo "codex mcp: unknown codex-sync-mcp='$value' (valid: true, false); falling back to true" >&2
      return 0
      ;;
  esac
}

codex_remove_mcp_sections() {
  local dst="$1" clean="$2" names_file="$3" tmp
  [[ -f "$dst" ]] || return 0
  tmp="$(mktemp "${TMPDIR:-/tmp}/cyncia-codex-config.XXXXXX")"
  awk -v clean="$clean" -v names_file="$names_file" '
    BEGIN {
      while ((getline n < names_file) > 0) wanted[n] = 1
      close(names_file)
      skip = 0
    }
    function section_name(line, rest, out, i, c) {
      if (line == "[mcp_servers]") return "__root__"
      if (line !~ /^\[mcp_servers\./) return ""
      rest = substr(line, length("[mcp_servers.") + 1)
      if (substr(rest, 1, 1) == "\"") {
        out = ""
        for (i = 2; i <= length(rest); i++) {
          c = substr(rest, i, 1)
          if (c == "\"") return out
          out = out c
        }
        return out
      }
      sub(/[.\]].*$/, "", rest)
      return rest
    }
    /^\[/ {
      n = section_name($0)
      if (n != "") {
        skip = (clean == "true" || (n != "__root__" && (n in wanted)))
      } else {
        skip = 0
      }
    }
    !skip { print }
  ' "$dst" > "$tmp"
  mv "$tmp" "$dst"
  if [[ ! -s "$dst" || -z "$(tr -d '[:space:]' < "$dst")" ]]; then
    rm -f "$dst"
  fi
}

codex_append_mcp_toml() {
  local dst="$1" generated="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" && -n "$(tr -d '[:space:]' < "$dst")" ]]; then
    printf '\n' >> "$dst"
  fi
  cat "$generated" >> "$dst"
}

if ! codex_mcp_enabled; then
  echo "codex mcp: skipped (codex-sync-mcp=false)"
  exit 0
fi

DST="$OUTPUT_DIR/.codex/config.toml"
mkdir -p "$(dirname "$DST")"

PAIRS="$(mcp_list_server_files "$INPUT_DIR")"
NAMES_FILE="$(mktemp "${TMPDIR:-/tmp}/cyncia-codex-mcp-names.XXXXXX")"
trap 'rm -f "${NAMES_FILE:-}" "${GENERATED_TOML:-}"' EXIT
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  printf '%s\n' "${line%%:*}" >> "$NAMES_FILE"
done <<< "$PAIRS"

if [[ -z "$PAIRS" ]]; then
  if [[ "$CLEAN" == "true" ]]; then
    codex_remove_mcp_sections "$DST" true "$NAMES_FILE"
    echo "codex mcp: cleaned mcp_servers in $DST (no matching servers)"
  else
    echo "codex mcp: no servers selected; skip"
  fi
  exit 0
fi

GENERATED_TOML="$(mktemp "${TMPDIR:-/tmp}/cyncia-codex-mcp.XXXXXX")"
mcp_emit_codex_toml "$INPUT_DIR" > "$GENERATED_TOML"
codex_remove_mcp_sections "$DST" "$CLEAN" "$NAMES_FILE"
codex_append_mcp_toml "$DST" "$GENERATED_TOML"
echo "codex mcp -> $DST"
