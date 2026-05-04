#!/usr/bin/env bash
# Copy <source_root>/AGENTS.md to <output_root>/AGENTS.md for Codex and,
# by default, write <output_root>/AGENTS.override.md with AGENTS.md plus rules.
#
# Codex discovers project guidance from AGENTS.override.md / AGENTS.md files,
# walking from the project root down to the current working directory.
# AGENTS.override.md is preferred over AGENTS.md in the same directory.
#
# Usage:
#   sync-agent-guidelines.sh -i <source_root> -o <output_root> [--clean] [--help]
#
#   --clean  When set: if input and output roots differ, remove output root
#            AGENTS.md before copy; remove AGENTS.override.md before regenerate.

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

rules_override_enabled() {
  local value
  value="$(read_cyncia_conf codex-rules-mode agents-override | tr '[:upper:]' '[:lower:]')"
  case "$value" in
    agents-override) return 0 ;;
    ignore) return 1 ;;
    *)
      echo "codex agent-guidelines: unknown codex-rules-mode='$value' (valid: agents-override, ignore); falling back to agents-override" >&2
      return 0
      ;;
  esac
}

OVERRIDE_DST="$OUTPUT_DIR/AGENTS.override.md"
if ! rules_override_enabled; then
  if [[ "$CLEAN" == "true" && -f "$OVERRIDE_DST" ]]; then
    rm -f "$OVERRIDE_DST"
    echo "codex agent-guidelines: removed $OVERRIDE_DST (--clean; codex-rules-mode=ignore)"
  else
    echo "codex agent-guidelines: skipped AGENTS.override.md (codex-rules-mode=ignore)"
  fi
  exit 0
fi

if [[ "$CLEAN" == "true" && -f "$OVERRIDE_DST" ]]; then
  rm -f "$OVERRIDE_DST"
  echo "codex agent-guidelines: removed $OVERRIDE_DST (--clean) before regenerate"
fi

RULES_DIR="$SRC_ROOT/rules"
{
  cat "$AGENTS_FILE"
  if [[ -d "$RULES_DIR" ]]; then
    shopt -s nullglob
    _rf=("$RULES_DIR"/*.md)
    _kept=()
    for _f in "${_rf[@]+"${_rf[@]}"}"; do
      _b="$(basename "$_f" .md)"
      [[ "$_b" == "README" ]] && continue
      _kept+=("$_f")
    done
    if [[ ${#_kept[@]} -gt 0 ]]; then
      printf '\n\n---\n\n## Project rules (from `rules/`)\n\n'
      while IFS= read -r f; do
        base="$(basename "$f" .md)"
        desc="$(extract_field "$f" description)"
        printf '### `%s.md`\n\n' "$base"
        if [[ -n "$desc" ]]; then
          printf '_%s_\n\n' "$desc"
        fi
        strip_frontmatter_normalize_headings "$f" 4
        printf '\n\n'
      done < <(printf '%s\n' "${_kept[@]}" | LC_ALL=C sort)
    fi
  fi
} > "$OVERRIDE_DST"

echo "codex agent-guidelines -> $OVERRIDE_DST (AGENTS.md + rules/*.md)"
