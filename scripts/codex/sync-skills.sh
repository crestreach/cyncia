#!/usr/bin/env bash
# Sync skills from <skills_dir>/<name>/ to <output_root>/.agents/skills/<name>/
# (full folder copy).
#
# Usage:
#   sync-skills.sh -i <skills_dir> -o <output_root> [--items name1,name2] [--clean] [--help]
#
#   --clean  Remove all subdirs under .agents/skills/ before syncing.

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
INPUT_DIR="$(to_abs_dir "$INPUT")"
OUTPUT_DIR="$(to_abs_dir "$OUTPUT")"

if [[ "$CLEAN" == "true" ]]; then
  clean_dir_contents "$OUTPUT_DIR/.agents/skills"
  echo "codex skills: cleaned $OUTPUT_DIR/.agents/skills/"
fi

codex_skill() {
  local name="$1" src="$2"
  local dst="$OUTPUT_DIR/.agents/skills/$name"
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
  # Codex does not document per-skill path gating; strip the generic field.
  apply_skill_rewrite "$dst" drop=applies-to
  echo "codex skill -> $dst/"
}

sync_items "$INPUT_DIR" dir codex_skill
