#!/usr/bin/env bash
# Sync skills from <skills_dir>/<name>/ to <output_root>/.github/skills/<name>/
# (full folder copy).
#
# Usage:
#   sync-skills.sh -i <skills_dir> -o <output_root> [--items name1,name2] [--clean] [--help]
#
#   --clean  Remove all subdirs under .github/skills/ before syncing.
#
# Examples (project root = output; input = examples/skills):
#   sync-skills.sh -i "$PWD/examples/skills" -o "$PWD"
#   sync-skills.sh -i "$PWD/examples/skills" -o "$PWD" --items delegate-to-aside

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
INPUT_DIR="$(to_abs_dir "$INPUT")"
OUTPUT_DIR="$(to_abs_dir "$OUTPUT")"

if [[ "$CLEAN" == "true" ]]; then
  clean_dir_contents "$OUTPUT_DIR/.github/skills"
  echo "copilot skills: cleaned $OUTPUT_DIR/.github/skills/"
fi

copilot_skill() {
  local name="$1" src="$2"
  local dst="$OUTPUT_DIR/.github/skills/$name"
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
  # Copilot skills do not support per-skill file scoping; strip applies-to.
  apply_skill_rewrite "$dst" drop=applies-to
  echo "copilot skill -> $dst/"
}

sync_items "$INPUT_DIR" dir copilot_skill
