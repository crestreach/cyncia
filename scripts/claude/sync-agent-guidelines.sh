#!/usr/bin/env bash
# Write <output_root>/CLAUDE.md from <source_root>/AGENTS.md plus each
# <source_root>/rules/<name>.md.
#
# Two emission modes are supported, selected by the `claude_rules_mode` key
# in `<cyncia-dir>/cyncia.conf` (default: `claude-md`):
#
#   claude-md    Append rule bodies into CLAUDE.md, grouped by source file.
#                Frontmatter is stripped; an optional `description` is shown
#                as an italic line under the heading. (Original behavior.)
#
#   rule-files   Reference each rule from CLAUDE.md via Claude Code's `@path`
#                memory-import syntax (one `@.claude/rules/<name>.md` line per
#                rule). The per-rule files themselves are written by
#                sync-rules.sh, so Claude Code loads each rule with the same
#                priority as CLAUDE.md.
#
# Skips rules/*.md with basename README.
#
# Usage:
#   sync-agent-guidelines.sh -i <source_root> -o <output_root> [--clean] [--help]
#
#   --clean  When set: if input and output roots differ, remove output root
#            AGENTS.md before copy; always remove output CLAUDE.md before writing.
#
# Examples:
#   sync-agent-guidelines.sh -i "$PWD/examples" -o "$PWD"
#   sync-agent-guidelines.sh -i "$PWD/.agent-config" -o "$PWD"

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
  echo "claude agent-guidelines: removed $OUTPUT_DIR/AGENTS.md (--clean) before copy"
fi

copy_agents_md_between_roots "$SRC_ROOT" "$OUTPUT_DIR"

DST="$OUTPUT_DIR/CLAUDE.md"
if [[ "$CLEAN" == "true" && -f "$DST" ]]; then
  rm -f "$DST"
  echo "claude agent-guidelines: removed $DST (--clean) before regenerate"
fi

RULES_DIR="$SRC_ROOT/rules"
MODE="$(read_cyncia_conf claude_rules_mode claude-md)"
case "$MODE" in
  claude-md|rule-files) ;;
  *)
    echo "claude agent-guidelines: unknown claude_rules_mode='$MODE' (valid: claude-md, rule-files); falling back to claude-md" >&2
    MODE="claude-md"
    ;;
esac

{
  cat "$AGENTS_FILE"
  if [[ -d "$RULES_DIR" ]]; then
    shopt -s nullglob
    _rf=("$RULES_DIR"/*.md)
    if [[ ${#_rf[@]} -gt 0 ]]; then
      # Filter out README.md (case-sensitive basename match).
      _kept=()
      for _f in "${_rf[@]}"; do
        _b="$(basename "$_f" .md)"
        [[ "$_b" == "README" ]] && continue
        _kept+=("$_f")
      done
      if [[ ${#_kept[@]} -gt 0 ]]; then
        if [[ "$MODE" == "rule-files" ]]; then
          printf '\n\n---\n\n## Project rules (from `rules/`)\n\n'
          while IFS= read -r f; do
            base="$(basename "$f" .md)"
            printf '@.claude/rules/%s.md\n' "$base"
          done < <(printf '%s\n' "${_kept[@]}" | LC_ALL=C sort)
          printf '\n'
        else
          printf '\n\n---\n\n## Project rules (from `rules/`)\n\n'
          while IFS= read -r f; do
            base="$(basename "$f" .md)"
            desc="$(extract_field "$f" description)"
            printf '### `%s.md`\n\n' "$base"
            if [[ -n "$desc" ]]; then
              printf '_%s_\n\n' "$desc"
            fi
            strip_frontmatter "$f"
            printf '\n\n'
          done < <(printf '%s\n' "${_kept[@]}" | LC_ALL=C sort)
        fi
      fi
    fi
  fi
} > "$DST"

if [[ "$MODE" == "rule-files" ]]; then
  echo "claude agent-guidelines -> $DST (AGENTS.md + @-imports for rules/*.md; mode=rule-files)"
else
  echo "claude agent-guidelines -> $DST (AGENTS.md + rules/*.md)"
fi
