#!/usr/bin/env bash
# Claude Code has no native per-rule file format. Rules from `rules/*.md` are
# merged into `CLAUDE.md` by `sync-agent-guidelines.sh` (not emitted as separate
# files). This script is a no-op for a uniform CLI (e.g. sync-all).
#
# Usage:
#   sync-rules.sh -i <ignored_source_dir> -o <output_root> [--clean] [--help]
#
#   --clean  No effect (per-rule content is produced by sync-agent-guidelines,
#            not this script). Accepted for a uniform CLI with other sync-rules.
#
# Examples:
#   sync-rules.sh -i "$PWD/examples/rules" -o "$PWD"
#   sync-rules.sh -i "$PWD/examples/rules" -o "$PWD" --clean

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
to_abs_dir "$INPUT" >/dev/null
to_abs_dir "$OUTPUT" >/dev/null

echo "claude rules -> skipped (per-rule content is merged into CLAUDE.md by sync-agent-guidelines)"
