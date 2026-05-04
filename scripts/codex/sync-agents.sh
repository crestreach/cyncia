#!/usr/bin/env bash
# Sync agents from <agents_dir>/*.md to <output_root>/.codex/agents/<name>.toml.
#
# Codex custom agents are TOML config layers. Generic Markdown agent bodies are
# written to developer_instructions; name and description come from frontmatter
# with the filename as fallback.
#
# Usage:
#   sync-agents.sh -i <agents_dir> -o <output_root> [--items name1,name2] [--clean] [--help]
#
#   --clean  Remove all files under .codex/agents/ before syncing.

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
INPUT_DIR="$(to_abs_dir "$INPUT")"
OUTPUT_DIR="$(to_abs_dir "$OUTPUT")"

if [[ "$CLEAN" == "true" ]]; then
  clean_dir_contents "$OUTPUT_DIR/.codex/agents"
  echo "codex agents: cleaned $OUTPUT_DIR/.codex/agents/"
fi

toml_escape_basic_string() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

toml_escape_multiline_basic() {
  awk '{ gsub(/\\/, "\\\\"); gsub(/"""/, "\\\"\\\"\\\""); print }'
}

codex_agent() {
  local name="$1" src="$2"
  local dst="$OUTPUT_DIR/.codex/agents/$name.toml"
  local agent_name desc
  agent_name="$(extract_field "$src" name)"
  desc="$(extract_field "$src" description)"
  [[ -z "$agent_name" ]] && agent_name="$name"
  [[ -z "$desc" ]] && desc="$name"
  mkdir -p "$(dirname "$dst")"
  {
    printf 'name = "%s"\n' "$(toml_escape_basic_string "$agent_name")"
    printf 'description = "%s"\n' "$(toml_escape_basic_string "$desc")"
    printf 'developer_instructions = """\n'
    strip_frontmatter "$src" | toml_escape_multiline_basic
    printf '\n"""\n'
  } > "$dst"
  echo "codex agent -> $dst"
}

sync_items "$INPUT_DIR" file codex_agent
