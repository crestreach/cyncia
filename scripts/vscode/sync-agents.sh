#!/usr/bin/env bash
# VS Code does not have its own project-level agent/skill/rule/guideline files.
# Those concepts belong to Copilot Chat (.github/...) or other tools, not to
# VS Code itself. This script is a no-op so that sync-all can iterate the
# vscode tool uniformly alongside cursor/claude/copilot/junie.
#
# Usage:
#   sync-agents.sh -i <agents_dir> -o <output_root> [--items ...] [--clean] [--help]
#
# It accepts the standard flags for parity but does not read or write anything.

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
echo "vscode agents: nothing to do (VS Code has no project-level agent files; see .github/agents for Copilot)"
