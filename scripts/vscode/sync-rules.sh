#!/usr/bin/env bash
# See sync-agents.sh: VS Code has no project-level rule files of its own.
# No-op for parity with other tools in sync-all.
#
# Usage:
#   sync-rules.sh -i <rules_dir> -o <output_root> [--items ...] [--clean] [--help]

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
echo "vscode rules: nothing to do (VS Code has no project-level rule files; see .github/instructions for Copilot)"
