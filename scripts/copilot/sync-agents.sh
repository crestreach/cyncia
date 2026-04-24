#!/usr/bin/env bash
# Sync agents from <agents_dir>/*.md to <output_root>/.github/agents/<name>.md.
#
# Usage:
#   sync-agents.sh -i <agents_dir> -o <output_root> [--items name1,name2] [--clean] [--help]
#
#   --clean  Remove all files under .github/agents/ before syncing.
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
  clean_dir_contents "$OUTPUT_DIR/.github/agents"
  echo "copilot agents: cleaned $OUTPUT_DIR/.github/agents/"
fi

copilot_agent() {
  local name="$1" src="$2"
  local dst="$OUTPUT_DIR/.github/agents/$name.md"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "copilot agent -> $dst"
}

sync_items "$INPUT_DIR" file copilot_agent
