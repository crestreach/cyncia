#!/usr/bin/env bash
# Copy <source_root>/AGENTS.md to <output_root>/.github/copilot-instructions.md.
#
# Usage:
#   sync-agent-guidelines.sh -i <source_root> -o <output_root> [--clean] [--help]
#
#   --clean  If input and output roots differ, remove root AGENTS.md before copy.
#            Remove .github/copilot-instructions.md before copy from the source
#            AGENTS.md.
#
# Examples:
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
  echo "copilot agent-guidelines: removed $OUTPUT_DIR/AGENTS.md (--clean) before copy"
fi

copy_agents_md_between_roots "$SRC_ROOT" "$OUTPUT_DIR"

DST="$OUTPUT_DIR/.github/copilot-instructions.md"
if [[ "$CLEAN" == "true" && -f "$DST" ]]; then
  rm -f "$DST"
  echo "copilot agent-guidelines: removed $DST (--clean) before copy"
fi
mkdir -p "$(dirname "$DST")"
cp "$AGENTS_FILE" "$DST"
echo "copilot agent-guidelines -> $DST"
