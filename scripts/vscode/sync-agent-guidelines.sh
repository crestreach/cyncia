#!/usr/bin/env bash
# See sync-agents.sh: VS Code has no top-level agent-guidelines file of its own.
# No-op for parity with other tools in sync-all.
#
# Usage:
#   sync-agent-guidelines.sh -i <source_root> -o <output_root> [--items ...] [--clean] [--help]

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
echo "vscode agent-guidelines: nothing to do (VS Code has no top-level agent guidelines file; see .github/copilot-instructions.md for Copilot)"
