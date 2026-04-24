#!/usr/bin/env bash
# See sync-agents.sh: VS Code has no project-level skill files of its own.
# No-op for parity with other tools in sync-all.
#
# Usage:
#   sync-skills.sh -i <skills_dir> -o <output_root> [--items ...] [--clean] [--help]

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
echo "vscode skills: nothing to do (VS Code has no project-level skill files; see .github/skills for Copilot)"
