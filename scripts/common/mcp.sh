#!/usr/bin/env bash
# Shared helpers for sync-mcp.sh scripts (Cursor / Claude / VS Code / Junie).
#
# Source AFTER common.sh:
#   source "$COMMON"
#   source "$MCP_COMMON"
#
# Requires: jq (1.6+). Call require_jq early.

# require_jq
#   Exit with a clear message if jq is not on PATH.
require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: 'jq' is required for sync-mcp scripts but was not found on PATH." >&2
    echo "Install it (macOS: 'brew install jq'; Debian/Ubuntu: 'apt-get install jq')." >&2
    exit 1
  fi
}

# mcp_list_server_files <input_dir>
#   Print absolute paths of selected *.json server files, one per line.
#   Respects $ITEMS (comma-separated basenames).
mcp_list_server_files() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "No source dir: $dir" >&2; exit 1
  fi

  shopt -s nullglob
  local -a all=()
  local f base
  for f in "$dir"/*.json; do
    base="$(basename "$f" .json)"
    all+=("$base")
  done

  local -a selected=()
  if [[ -n "$ITEMS" ]]; then
    local _item
    IFS=',' read -r -a selected <<< "$ITEMS"
    local -a _trimmed=()
    for _item in "${selected[@]+"${selected[@]}"}"; do
      _item="${_item#"${_item%%[![:space:]]*}"}"
      _item="${_item%"${_item##*[![:space:]]}"}"
      _trimmed+=("$_item")
    done
    selected=("${_trimmed[@]+"${_trimmed[@]}"}")
  else
    selected=("${all[@]+"${all[@]}"}")
  fi

  local name path
  for name in "${selected[@]+"${selected[@]}"}"; do
    path="$dir/$name.json"
    if [[ ! -f "$path" ]]; then
      echo "skip: $name (not a file at $path)" >&2; continue
    fi
    echo "$name:$path"
  done
}

# mcp_translate_body_cursor <server_json_file>
#   Print the per-server body JSON with ${secret:NAME[?optional]} rewritten
#   to ${env:NAME}.
mcp_translate_body_cursor() {
  jq '
    walk(
      if type == "string" then
        gsub("\\$\\{secret:(?<n>[A-Za-z_][A-Za-z0-9_]*)(\\?optional)?\\}"; "${env:" + .n + "}")
      else . end
    )
  ' "$1"
}

# mcp_translate_body_claude <server_json_file>
#   Required secrets become ${NAME}; optional secrets become ${NAME:-}.
mcp_translate_body_claude() {
  jq '
    walk(
      if type == "string" then
        gsub("\\$\\{secret:(?<n>[A-Za-z_][A-Za-z0-9_]*)\\?optional\\}"; "${" + .n + ":-}")
        | gsub("\\$\\{secret:(?<n>[A-Za-z_][A-Za-z0-9_]*)\\}"; "${" + .n + "}")
      else . end
    )
  ' "$1"
}

# mcp_translate_body_vscode <server_json_file>
#   Secrets become ${input:NAME}. Emits body to stdout.
#   (VS Code's .vscode/mcp.json format; also read by Copilot Chat in VS Code.)
mcp_translate_body_vscode() {
  jq '
    walk(
      if type == "string" then
        gsub("\\$\\{secret:(?<n>[A-Za-z_][A-Za-z0-9_]*)(\\?optional)?\\}"; "${input:" + .n + "}")
      else . end
    )
  ' "$1"
}

# mcp_extract_inputs_vscode <server_json_file>
#   Print a JSON array of VS Code input entries for every ${secret:NAME[?optional]}
#   token found in the body. Required -> no default; optional -> default "".
#   Deduplicates by id; if the same id appears both required and optional, the
#   optional form wins (default "" so the prompt can be skipped).
mcp_extract_inputs_vscode() {
  # Collect strings, scan each for secret tokens, sort, then group by id.
  jq '
    [.. | strings]
    | map([scan("\\$\\{secret:([A-Za-z_][A-Za-z0-9_]*)(\\?optional)?\\}")])
    | map(.[])
    | map({id: .[0], optional: (.[1] == "?optional")})
    | sort_by(.id)
    | group_by(.id)
    | map({id: .[0].id, optional: (any(.[]; .optional))})
    | map(
        if .optional then
          {id: .id, type: "promptString", description: (.id + " (optional)"), password: true, default: ""}
        else
          {id: .id, type: "promptString", description: .id, password: true}
        end
      )
  ' "$1"
}

# mcp_assemble_servers <top_key> <translator_fn> <input_dir>
#   Build { "<top_key>": { name1: body1, ... } } from selected server files,
#   translating each body with the given per-tool function.
mcp_assemble_servers() {
  local top_key="$1" translator="$2" input_dir="$3"
  local result
  result="$(jq -n --arg k "$top_key" '{($k): {}}')"
  local line name path body
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name="${line%%:*}"
    path="${line#*:}"
    body="$("$translator" "$path")"
    result="$(jq -n --argjson acc "$result" --arg top "$top_key" --arg k "$name" --argjson v "$body" \
      '$acc | .[$top] += {($k): $v}')"
  done < <(mcp_list_server_files "$input_dir")
  echo "$result"
}

# mcp_collect_inputs_vscode <input_dir>
#   Concatenate input arrays from every selected server file, deduped by id.
#   Optional wins over required if both appear.
mcp_collect_inputs_vscode() {
  local input_dir="$1"
  local all='[]'
  local line name path part
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    path="${line#*:}"
    part="$(mcp_extract_inputs_vscode "$path")"
    all="$(jq -n --argjson a "$all" --argjson b "$part" '$a + $b')"
  done < <(mcp_list_server_files "$input_dir")
  jq '
    sort_by(.id)
    | group_by(.id)
    | map(
        if any(.[]; has("default")) then
          (map(select(has("default"))) | .[0])
        else .[0] end
      )
  ' <<< "$all"
}
