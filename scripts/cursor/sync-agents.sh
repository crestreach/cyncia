#!/usr/bin/env bash
# Sync agents from <agents_dir>/*.md to <output_root>/.cursor/agents/<name>.md.
#
# Usage:
#   sync-agents.sh -i <agents_dir> -o <output_root> [--items name1,name2] [--clean] [--help]
#
#   --clean  Before syncing, remove all existing files under .cursor/agents/ so
#            agents removed from the source tree do not remain in the output.
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
  clean_dir_contents "$OUTPUT_DIR/.cursor/agents"
  echo "cursor agents: cleaned $OUTPUT_DIR/.cursor/agents/"
fi

cursor_agent() {
  local name="$1" src="$2"
  local dst="$OUTPUT_DIR/.cursor/agents/$name.md"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "cursor agent -> $dst"
}

sync_items "$INPUT_DIR" file cursor_agent
