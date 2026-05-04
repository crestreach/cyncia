#!/usr/bin/env bash
# Codex rule emission for generic rules/<name>.md.
#
# No .codex/rules files are generated. Cyncia rules are Markdown instruction
# snippets with applies-to/always-apply metadata. Codex's native .rules files
# are Starlark command execution policy, so generating them from Markdown would
# be invalid. Markdown rules are merged into AGENTS.override.md by
# sync-agent-guidelines.sh when codex-rules-mode is agents-override.
# Put Codex command approval policy in .codex/rules/*.rules by hand.
#
# Usage:
#   sync-rules.sh -i <rules_dir> -o <output_root> [--items name1,name2] [--clean] [--help]
#
#   --items  Accepted for CLI parity; ignored.
#   --clean  Accepted for CLI parity; no files are removed.

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
to_abs_dir "$INPUT" >/dev/null
to_abs_dir "$OUTPUT" >/dev/null

echo "codex rules -> skipped (.codex/rules are Starlark command policy; Markdown rules are handled by codex sync-agent-guidelines when codex-rules-mode=agents-override)"
