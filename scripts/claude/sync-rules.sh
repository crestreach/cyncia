#!/usr/bin/env bash
# Claude Code rule emission for `rules/<name>.md`.
#
# Behavior depends on the `claude-rules-mode` key in <cyncia-dir>/cyncia.conf
# (default: `claude-md`):
#
#   claude-md    No-op. Rule bodies are merged into CLAUDE.md by
#                sync-agent-guidelines.sh.
#
#   rule-files   Write each rule to <output_root>/.claude/rules/<name>.md, with
#                YAML frontmatter stripped (an optional `description` is shown
#                as an italic line under the heading). Claude Code loads these
#                files as memory imports referenced from CLAUDE.md, with the
#                same priority as CLAUDE.md.
#
# Usage:
#   sync-rules.sh -i <rules_dir> -o <output_root> [--items name1,name2] [--clean] [--help]
#
#   --clean  In rule-files mode: remove every existing file under
#            <output_root>/.claude/rules/ so rules removed from the source
#            do not leave stale outputs. No effect in claude-md mode.
#
# Examples:
#   sync-rules.sh -i "$PWD/examples/rules" -o "$PWD"
#   sync-rules.sh -i "$PWD/examples/rules" -o "$PWD" --clean

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
INPUT_DIR="$(to_abs_dir "$INPUT")"
OUTPUT_DIR="$(to_abs_dir "$OUTPUT")"

MODE="$(read_cyncia_conf claude-rules-mode claude-md)"
case "$MODE" in
  claude-md|rule-files) ;;
  *)
    echo "claude rules: unknown claude-rules-mode='$MODE' (valid: claude-md, rule-files); falling back to claude-md" >&2
    MODE="claude-md"
    ;;
esac

if [[ "$MODE" != "rule-files" ]]; then
  echo "claude rules -> skipped (mode=claude-md; per-rule content is merged into CLAUDE.md by sync-agent-guidelines)"
  exit 0
fi

if [[ "$CLEAN" == "true" ]]; then
  clean_dir_contents "$OUTPUT_DIR/.claude/rules"
  echo "claude rules: cleaned $OUTPUT_DIR/.claude/rules/"
fi

claude_rule_file() {
  local name="$1" src="$2"
  local dst="$OUTPUT_DIR/.claude/rules/$name.md"
  local desc
  desc="$(extract_field "$src" description)"
  mkdir -p "$(dirname "$dst")"
  {
    printf '# `%s.md`\n\n' "$name"
    if [[ -n "$desc" ]]; then
      printf '_%s_\n\n' "$desc"
    fi
    strip_frontmatter "$src"
  } > "$dst"
  echo "claude rule -> $dst"
}

sync_items "$INPUT_DIR" file claude_rule_file
