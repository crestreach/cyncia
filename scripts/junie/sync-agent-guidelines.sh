#!/usr/bin/env bash
# Write <output_root>/.junie/AGENTS.md from <source_root>/AGENTS.md plus each
# <source_root>/rules/<name>.md (Junie has no native per-rule files; rule bodies
# are appended here, grouped by source file).
#
# Usage:
#   sync-agent-guidelines.sh -i <source_root> -o <output_root> [--clean] [--help]
#
#   --clean  When set: if input and output roots differ, remove output root
#            AGENTS.md before copy; remove output .junie/AGENTS.md before writing.
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
  echo "junie agent-guidelines: removed $OUTPUT_DIR/AGENTS.md (--clean) before copy"
fi

copy_agents_md_between_roots "$SRC_ROOT" "$OUTPUT_DIR"

DST="$OUTPUT_DIR/.junie/AGENTS.md"
if [[ "$CLEAN" == "true" && -f "$DST" ]]; then
  rm -f "$DST"
  echo "junie agent-guidelines: removed $DST (--clean) before write"
fi
mkdir -p "$(dirname "$DST")"
RULES_DIR="$SRC_ROOT/rules"

{
  cat "$AGENTS_FILE"
  if [[ -d "$RULES_DIR" ]]; then
    shopt -s nullglob
    _rf=("$RULES_DIR"/*.md)
    if [[ ${#_rf[@]} -gt 0 ]]; then
      printf '\n\n---\n\n## Project rules (from `rules/`)\n\n'
      while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        base="$(basename "$f" .md)"
        [[ "$base" == "README" ]] && continue
        desc="$(extract_field "$f" description)"
        printf '### `%s.md`\n\n' "$base"
        if [[ -n "$desc" ]]; then
          printf '_%s_\n\n' "$desc"
        fi
        strip_frontmatter "$f"
        printf '\n\n'
      done < <(printf '%s\n' "${_rf[@]}" | LC_ALL=C sort)
    fi
  fi
} > "$DST"

echo "junie agent-guidelines -> $DST (AGENTS.md + rules/*.md)"
