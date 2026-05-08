#!/usr/bin/env bash
# VS Code custom agents for a workspace are the Copilot .github/agents/*.agent.md
# files handled by scripts/copilot/sync-agents.sh. This script is a no-op so
# sync-all can iterate the vscode tool uniformly alongside other tools.
#
# Usage:
#   sync-agents.sh -i <agents_dir> -o <output_root> [--items ...] [--clean] [--help]
#
# It accepts the standard flags for parity but does not read or write anything.

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
source "$COMMON"

parse_io_args "$@"
echo "vscode agents: nothing to do (workspace agents are written by copilot to .github/agents/*.agent.md)"
