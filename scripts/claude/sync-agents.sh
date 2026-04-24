#!/usr/bin/env bash
# Sync agents from <agents_dir>/*.md to <output_root>/.claude/agents/<name>.md.
#
# Usage:
#   sync-agents.sh -i <agents_dir> -o <output_root> [--items name1,name2] [--clean] [--help]
#
#   --clean  Remove all files under .claude/agents/ before syncing.
#
# Examples (project root = output; input = examples/agents):
#   sync-agents.sh -i "$PWD/examples/agents" -o "$PWD"
#   sync-agents.sh -i "$PWD/examples/agents" -o "$PWD" --items aside

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
INPUT_DIR="$(to_abs_dir "$INPUT")"
OUTPUT_DIR="$(to_abs_dir "$OUTPUT")"

if [[ "$CLEAN" == "true" ]]; then
  clean_dir_contents "$OUTPUT_DIR/.claude/agents"
  echo "claude agents: cleaned $OUTPUT_DIR/.claude/agents/"
fi

claude_agent() {
  local name="$1" src="$2"
  local dst="$OUTPUT_DIR/.claude/agents/$name.md"
  mkdir -p "$(dirname "$dst")"
  # Drop generic 'mcp-servers' from frontmatter; inject native 'mcpServers'.
  rewrite_skill_frontmatter "$src" "drop=mcp-servers" > "$dst"
  local mcp
  mcp="$(extract_field "$src" mcp-servers)"
  if [[ -n "$mcp" ]]; then
    insert_fm_line "$dst" "mcpServers: $(mcp_csv_to_yaml_flow_list "$mcp")"
  fi
  echo "claude agent -> $dst"
}

sync_items "$INPUT_DIR" file claude_agent
