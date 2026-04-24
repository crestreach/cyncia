#!/usr/bin/env bash
# Cursor reads AGENTS.md at the output project root. This script only checks
# that the source tree contains AGENTS.md (-i is the source root directory).
#
# Usage:
#   sync-agent-guidelines.sh -i <source_root> -o <output_root> [--clean] [--help]
#
#   --clean  If input and output roots differ, remove the existing root AGENTS.md
#            before copying (default is overwrite in place).
#
# Examples (source tree with AGENTS.md; output = project root):
#   sync-agent-guidelines.sh -i "$PWD/examples" -o "$PWD"
#   sync-agent-guidelines.sh -i "$PWD/_internal" -o "$PWD"

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
SRC_ROOT="$(to_abs_dir "$INPUT")"
OUTPUT_DIR="$(to_abs_dir "$OUTPUT")"
AGENTS_FILE="$SRC_ROOT/AGENTS.md"
if [[ ! -f "$AGENTS_FILE" ]]; then
  echo "Missing $AGENTS_FILE" >&2; exit 1
fi

if [[ "$CLEAN" == "true" && "$SRC_ROOT" != "$OUTPUT_DIR" && -f "$OUTPUT_DIR/AGENTS.md" ]]; then
  rm -f "$OUTPUT_DIR/AGENTS.md"
  echo "cursor agent-guidelines: removed $OUTPUT_DIR/AGENTS.md (--clean) before copy"
fi

copy_agents_md_between_roots "$SRC_ROOT" "$OUTPUT_DIR"

echo "cursor agent-guidelines -> Cursor uses $OUTPUT_DIR/AGENTS.md (synced from source tree when roots differ)"
