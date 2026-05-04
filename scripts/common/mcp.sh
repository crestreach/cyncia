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

# mcp_emit_codex_toml <input_dir>
#   Print Codex project config TOML with one [mcp_servers.<name>] table per
#   selected server. Codex reads this from .codex/config.toml.
#
#   Generic source uses JSON shaped for VS Code/Cursor/Claude. Codex stores MCP
#   in TOML and reads secrets from environment variables. Exact env secret values
#   ("${secret:NAME}") are translated to env_vars = ["NAME"] when the env key
#   is the same name. HTTP Authorization headers of the form
#   "Bearer ${secret:NAME}" are translated to bearer_token_env_var = "NAME".
mcp_emit_codex_toml() {
  local input_dir="$1"
  local first=true line name path
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name="${line%%:*}"
    path="${line#*:}"
    if [[ "$first" == "true" ]]; then
      first=false
    else
      printf '\n'
    fi
    jq -r --arg name "$name" '
      def q: @json;
      def bare_secret_re: "^\\$\\{secret:(?<n>[A-Za-z_][A-Za-z0-9_]*)(\\?optional)?\\}$";
      def bearer_secret_re: "^Bearer \\$\\{secret:(?<n>[A-Za-z_][A-Za-z0-9_]*)(\\?optional)?\\}$";
      def has_secret: type == "string" and test("\\$\\{secret:");
      def no_secret($field):
        if has_secret then error("codex mcp: unsupported secret token in " + $field) else . end;
      def secret_name: capture(bare_secret_re).n;
      def bearer_secret_name: capture(bearer_secret_re).n;
      def str_array($field):
        map(if type == "string" then no_secret($field) else error("codex mcp: " + $field + " must contain strings") end);
      def kv_lines($table; $entries):
        if ($entries | length) == 0 then []
        else ["", $table] + ($entries | sort_by(.key) | map((.key | q) + " = " + (.value | q))) end;

      . as $server
      | ($server.type // (if $server.command then "stdio" else "streamable_http" end)) as $type
      | if ($type == "stdio") then
          ($server.env // {}) as $env
          | ($env | to_entries | map(select(.value | type == "string" and test(bare_secret_re)))) as $secret_env_entries
          | ($secret_env_entries | map(. as $e | ($e.value | secret_name) as $n | if $n == $e.key then $n else error("codex mcp: env secret for " + $name + "." + $e.key + " must use the same variable name") end)) as $secret_env_vars
          | ($env | to_entries | map(select((.value | type == "string" and test(bare_secret_re)) | not))) as $static_env_entries
          | if ($server.command | type) != "string" then
              error("codex mcp: stdio server " + $name + " requires command")
            elif ($env | type) != "object" then
              error("codex mcp: env must be an object for " + $name)
            elif ($static_env_entries | any(.value | has_secret)) then
              error("codex mcp: unsupported embedded secret token in env for " + $name)
            else
              (["[mcp_servers." + ($name | q) + "]",
                "command = " + (($server.command | no_secret("command")) | q)]
                + (if ($server.args? // null) == null then [] else ["args = " + (($server.args | str_array("args")) | q)] end)
                + (if ($server.cwd? // null) == null then [] else ["cwd = " + (($server.cwd | no_secret("cwd")) | q)] end)
                + (if (($server.env_vars? // []) + $secret_env_vars | length) == 0 then [] else ["env_vars = " + ((($server.env_vars? // []) + $secret_env_vars) | q)] end)
                + (if ($server.startup_timeout_sec? // null) == null then [] else ["startup_timeout_sec = " + ($server.startup_timeout_sec | tostring)] end)
                + (if ($server.tool_timeout_sec? // null) == null then [] else ["tool_timeout_sec = " + ($server.tool_timeout_sec | tostring)] end)
                + (if ($server.enabled? // null) == null then [] else ["enabled = " + ($server.enabled | tostring)] end)
                + (if ($server.required? // null) == null then [] else ["required = " + ($server.required | tostring)] end)
                + (if ($server.enabled_tools? // null) == null then [] else ["enabled_tools = " + (($server.enabled_tools | str_array("enabled_tools")) | q)] end)
                + (if ($server.disabled_tools? // null) == null then [] else ["disabled_tools = " + (($server.disabled_tools | str_array("disabled_tools")) | q)] end)
                + kv_lines("[mcp_servers." + ($name | q) + ".env]"; $static_env_entries))[]
            end
        elif ($type == "http" or $type == "streamable_http") then
          (($server.headers // $server.http_headers // {}) | to_entries) as $headers
          | ($headers | map(select(.key == "Authorization" and (.value | type == "string" and test(bearer_secret_re))))) as $bearer_entries
          | ($headers | map(select((.key == "Authorization" and (.value | type == "string" and test(bearer_secret_re))) | not))) as $non_bearer_headers
          | ($non_bearer_headers | map(select(.value | type == "string" and test(bare_secret_re)) | {key, value: (.value | secret_name)})) as $env_header_entries
          | ($non_bearer_headers | map(select((.value | type == "string" and test(bare_secret_re)) | not))) as $static_header_entries
          | if ($server.url | type) != "string" then
              error("codex mcp: HTTP server " + $name + " requires url")
            elif ($bearer_entries | length) > 1 then
              error("codex mcp: multiple Authorization bearer secrets for " + $name)
            elif ($static_header_entries | any(.value | has_secret)) then
              error("codex mcp: unsupported embedded secret token in headers for " + $name)
            else
              (["[mcp_servers." + ($name | q) + "]",
                "url = " + (($server.url | no_secret("url")) | q)]
                + (if ($server.bearer_token_env_var? // null) != null then ["bearer_token_env_var = " + ($server.bearer_token_env_var | q)] elif ($bearer_entries | length) == 1 then ["bearer_token_env_var = " + (($bearer_entries[0].value | bearer_secret_name) | q)] else [] end)
                + (if ($server.startup_timeout_sec? // null) == null then [] else ["startup_timeout_sec = " + ($server.startup_timeout_sec | tostring)] end)
                + (if ($server.tool_timeout_sec? // null) == null then [] else ["tool_timeout_sec = " + ($server.tool_timeout_sec | tostring)] end)
                + (if ($server.enabled? // null) == null then [] else ["enabled = " + ($server.enabled | tostring)] end)
                + (if ($server.required? // null) == null then [] else ["required = " + ($server.required | tostring)] end)
                + (if ($server.enabled_tools? // null) == null then [] else ["enabled_tools = " + (($server.enabled_tools | str_array("enabled_tools")) | q)] end)
                + (if ($server.disabled_tools? // null) == null then [] else ["disabled_tools = " + (($server.disabled_tools | str_array("disabled_tools")) | q)] end)
                + kv_lines("[mcp_servers." + ($name | q) + ".http_headers]"; $static_header_entries)
                + kv_lines("[mcp_servers." + ($name | q) + ".env_http_headers]"; $env_header_entries))[]
            end
        else
          error("codex mcp: unsupported server type for " + $name + ": " + ($type | tostring))
        end
    ' "$path"
  done < <(mcp_list_server_files "$input_dir")
}
