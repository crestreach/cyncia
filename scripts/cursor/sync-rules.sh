#!/usr/bin/env bash
# Sync rules from <rules_dir>/*.md to <output_root>/.cursor/rules/<name>.mdc
# with Cursor's frontmatter: description, globs, alwaysApply.
#
# Translation of generic source fields:
#   applies-to: "..."   ->  globs: ...
#   always-apply: true  ->  alwaysApply: true
#
# Usage:
#   sync-rules.sh -i <rules_dir> -o <output_root> [--items name1,name2] [--clean] [--help]
#
#   --clean  Before syncing, remove all existing .mdc files under .cursor/rules/
#            so rules removed from the source tree do not remain in the output.
#
# Examples (project root = output; input = examples/rules):
#   sync-rules.sh -i "$PWD/examples/rules" -o "$PWD"
#   sync-rules.sh -i "$PWD/examples/rules" -o "$PWD" --items java-conventions,commit-style

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
INPUT_DIR="$(to_abs_dir "$INPUT")"
OUTPUT_DIR="$(to_abs_dir "$OUTPUT")"

if [[ "$CLEAN" == "true" ]]; then
  clean_dir_contents "$OUTPUT_DIR/.cursor/rules"
  echo "cursor rules: cleaned $OUTPUT_DIR/.cursor/rules/"
fi

cursor_rule() {
  local name="$1" src="$2"
  local dst="$OUTPUT_DIR/.cursor/rules/$name.mdc"
  local desc globs always
  desc="$(extract_field "$src" description)"
  globs="$(extract_field "$src" applies-to)"
  always="$(extract_field "$src" always-apply)"
  [[ -z "$desc" ]] && desc="$name"
  [[ "$always" != "true" ]] && always="false"
  mkdir -p "$(dirname "$dst")"
  {
    printf -- '---\n'
    printf 'description: %s\n' "$desc"
    if [[ -n "$globs" ]]; then
      printf 'globs: %s\n' "$globs"
    fi
    printf 'alwaysApply: %s\n' "$always"
    printf -- '---\n\n'
    strip_frontmatter "$src"
  } > "$dst"
  echo "cursor rule -> $dst"
}

sync_items "$INPUT_DIR" file cursor_rule
