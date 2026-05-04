#!/usr/bin/env bash
# Copy <source_root>/AGENTS.md to <output_root>/AGENTS.md for Codex.
#
# Codex discovers project guidance from AGENTS.md files, walking from the
# project root down to the current working directory. This repo emits the root
# project AGENTS.md only; nested AGENTS.md files remain hand-authored.
#
# Usage:
#   sync-agent-guidelines.sh -i <source_root> -o <output_root> [--clean] [--help]
#
#   --clean  When set: if input and output roots differ, remove output root
#            AGENTS.md before copy.

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
  echo "codex agent-guidelines: removed $OUTPUT_DIR/AGENTS.md (--clean) before copy"
fi

copy_agents_md_between_roots "$SRC_ROOT" "$OUTPUT_DIR"
echo "codex agent-guidelines -> $OUTPUT_DIR/AGENTS.md"
