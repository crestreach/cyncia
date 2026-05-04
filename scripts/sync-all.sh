#!/usr/bin/env bash
# Run every sync-*.sh script for the requested tools. Expects a single source
# tree containing AGENTS.md plus any of agents/, rules/, skills/, mcp-servers/
# (all four are optional), and one output project root.
#
# Usage:
#   sync-all.sh -i <source_root> -o <output_root> [--tools cursor,claude,copilot,vscode,junie,codex] [--items a,b,c] [--clean]
#
#   <source_root>  Must contain AGENTS.md. May optionally contain any of:
#                    agents/        (one *.md per agent)
#                    skills/        (one folder per skill, with SKILL.md)
#                    rules/         (one *.md per rule)
#                    mcp-servers/   (one *.json per MCP server)
#                  Each subscript is skipped when its source dir is absent.
#   <output_root>  Project root where tool-specific files are written (.cursor, …)
#                  Each sync-agent-guidelines copies AGENTS.md here when i≠o.
#   --tools        Comma-separated tool list. Defaults to the `default-tools`
#                  value in cyncia.conf, or all supported tools when unset.
#   --clean        Forwarded to every per-tool script: clear that script’s
#                  output location(s) before writing (default: off). See each
#                  sync-*.sh header for what is removed.
#
# Examples (sources under examples/; output = project root):
#   sync-all.sh -i "$PWD/examples" -o "$PWD"
#   sync-all.sh -i "$PWD/examples" -o "$PWD" --tools cursor,claude --items delegate-to-aside

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/common.sh"

DEFAULT_TOOLS="cursor,claude,copilot,vscode,junie,codex"
TOOLS=""
ITEMS=""
INPUT_BASE=""
OUTPUT_BASE=""
SYNC_ALL_CLEAN=false

_print_usage() { sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; }
_require_value() {
  local flag="$1" argc="$2"
  if [[ "$argc" -lt 2 ]]; then echo "Error: $flag requires a value." >&2; echo >&2; _print_usage >&2; exit 2; fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input)  _require_value "$1" "$#"; INPUT_BASE="$2"; shift 2;;
    -o|--output) _require_value "$1" "$#"; OUTPUT_BASE="$2"; shift 2;;
    --tools)     _require_value "$1" "$#"; TOOLS="$2"; shift 2;;
    --items)     _require_value "$1" "$#"; ITEMS="$2"; shift 2;;
    --clean)     SYNC_ALL_CLEAN=true; shift;;
    -h|--help)   _print_usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; echo >&2; _print_usage >&2; exit 2;;
  esac
done

if [[ -z "$INPUT_BASE" || -z "$OUTPUT_BASE" ]]; then
  echo "Error: -i/--input and -o/--output are required." >&2
  echo >&2
  _print_usage >&2
  exit 2
fi

# Normalize to absolute paths (source tree must exist).
if [[ ! -d "$INPUT_BASE" ]]; then
  echo "Not a directory: $INPUT_BASE" >&2; exit 1
fi
INPUT_BASE="$(cd "$INPUT_BASE" && pwd)"
if [[ ! -d "$OUTPUT_BASE" ]]; then
  echo "Not a directory: $OUTPUT_BASE" >&2; exit 1
fi
OUTPUT_BASE="$(cd "$OUTPUT_BASE" && pwd)"

AGENTS_FILE="$INPUT_BASE/AGENTS.md"
if [[ ! -f "$AGENTS_FILE" ]]; then
  echo "Missing $AGENTS_FILE" >&2; exit 1
fi

if [[ -z "$TOOLS" ]]; then
  TOOLS="$(read_cyncia_conf default-tools "$DEFAULT_TOOLS")"
fi

IFS=',' read -r -a TOOL_LIST <<< "$TOOLS"

# Optional --items and --clean: avoid ${arr[@]} with set -u when array is empty (bash 4.4+).
run_sync() {
  local s="$1"
  shift
  if [[ -n "$ITEMS" && "$SYNC_ALL_CLEAN" == "true" ]]; then
    bash "$s" "$@" --items "$ITEMS" --clean
  elif [[ -n "$ITEMS" ]]; then
    bash "$s" "$@" --items "$ITEMS"
  elif [[ "$SYNC_ALL_CLEAN" == "true" ]]; then
    bash "$s" "$@" --clean
  else
    bash "$s" "$@"
  fi
}

for tool in "${TOOL_LIST[@]}"; do
  tool="$(echo "$tool" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
  [[ -z "$tool" ]] && continue
  dir="$SCRIPT_DIR/$tool"
  if [[ ! -d "$dir" ]]; then
    echo "Unknown tool: $tool" >&2; exit 1
  fi
  echo "== $tool =="
  if [[ -d "$INPUT_BASE/agents" ]]; then
    run_sync "$dir/sync-agents.sh"      -i "$INPUT_BASE/agents"   -o "$OUTPUT_BASE"
  else
    echo "$tool agents: skipped (no $INPUT_BASE/agents)"
  fi
  if [[ -d "$INPUT_BASE/skills" ]]; then
    run_sync "$dir/sync-skills.sh"      -i "$INPUT_BASE/skills"  -o "$OUTPUT_BASE"
  else
    echo "$tool skills: skipped (no $INPUT_BASE/skills)"
  fi
  if [[ -d "$INPUT_BASE/mcp-servers" ]]; then
    run_sync "$dir/sync-mcp.sh"       -i "$INPUT_BASE/mcp-servers" -o "$OUTPUT_BASE"
  fi
  run_sync "$dir/sync-agent-guidelines.sh" -i "$INPUT_BASE" -o "$OUTPUT_BASE"
  if [[ -d "$INPUT_BASE/rules" ]]; then
    run_sync "$dir/sync-rules.sh"       -i "$INPUT_BASE/rules" -o "$OUTPUT_BASE"
  else
    echo "$tool rules: skipped (no $INPUT_BASE/rules)"
  fi
done
