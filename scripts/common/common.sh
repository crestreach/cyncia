#!/usr/bin/env bash
# Shared helpers for per-tool sync scripts.
# Source from a per-tool script, e.g. scripts/cursor/sync-agents.sh:
#
#   COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../common" && pwd)/common.sh"
#   source "$COMMON"
#
# After sourcing:
#   call parse_io_args "$@" to set $INPUT, $OUTPUT, $ITEMS and handle --help.
#   call sync_items <src_dir> <file|dir> <handler_fn> to iterate.

set -euo pipefail

# Globals set by parse_io_args.
INPUT=""
OUTPUT=""
ITEMS=""
# Set to true when --clean is passed: remove existing generated files in the
# script’s output location(s) before writing, so removed sources do not leave
# stale outputs behind.
CLEAN=false

# clean_dir_contents <dir>
#   Remove every child of an existing directory (the directory itself remains).
clean_dir_contents() {
  local d="$1"
  [[ -d "$d" ]] || return 0
  find "$d" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

# Print the caller script's leading "# ..." comment block (help text).
_print_help_from_caller() {
  local caller="${1:-${BASH_SOURCE[1]}}"
  awk 'NR>1 { if (/^#/) { sub(/^# ?/,""); print } else if ($0!="") exit }' "$caller"
}

# to_abs_dir <path> — must exist as a directory.
to_abs_dir() {
  local p="$1"
  if [[ -z "$p" ]]; then echo "Empty path" >&2; return 1; fi
  if [[ ! -d "$p" ]]; then echo "Not a directory: $p" >&2; return 1; fi
  (cd "$p" && pwd)
}

# to_abs_file <path> — must exist as a regular file.
to_abs_file() {
  local p="$1"
  if [[ -z "$p" ]]; then echo "Empty path" >&2; return 1; fi
  if [[ ! -f "$p" ]]; then echo "Not a file: $p" >&2; return 1; fi
  echo "$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
}

# copy_agents_md_between_roots <source_root> <output_root>
#   Copies <source_root>/AGENTS.md to <output_root>/AGENTS.md when the two
#   directory paths differ. No file operation when they are the same
#   (e.g. sync-all to the same tree).
copy_agents_md_between_roots() {
  local src_root="$1" out_root="$2"
  if [[ "$src_root" == "$out_root" ]]; then
    echo "agent-guidelines: skip AGENTS.md copy (input and output root are the same: $src_root)"
    return 0
  fi
  local src="$src_root/AGENTS.md" dst="$out_root/AGENTS.md"
  if [[ ! -f "$src" ]]; then
    echo "Missing $src" >&2
    return 1
  fi
  cp "$src" "$dst"
  echo "agent-guidelines: copied $src -> $dst"
}

# _require_flag_value <caller_script> <flag_name> <argc_remaining>
#   Exits 2 if a value-taking flag has no following argument.
_require_flag_value() {
  local rcaller="$1" flag="$2" argc="$3"
  if [[ "$argc" -lt 2 ]]; then
    echo "Error: $flag requires a value." >&2; echo >&2; _print_help_from_caller "$rcaller" >&2; exit 2
  fi
}

# parse_io_args "$@"
#   Sets $INPUT, $OUTPUT, $ITEMS from -i/--input, -o/--output, --items.
#   Sets $CLEAN=true if --clean is present (default false).
#   -h/--help prints the caller's header comment and exits 0.
#   On missing/invalid input, prints error, help, and exits 2.
parse_io_args() {
  local caller="${BASH_SOURCE[1]}"
  INPUT=""
  OUTPUT=""
  ITEMS=""
  CLEAN=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i|--input)
        _require_flag_value "$caller" "$1" "$#"
        INPUT="$2"; shift 2;;
      -o|--output)
        _require_flag_value "$caller" "$1" "$#"
        OUTPUT="$2"; shift 2;;
      --items)
        _require_flag_value "$caller" "$1" "$#"
        ITEMS="$2"; shift 2;;
      --clean)     CLEAN=true; shift;;
      -h|--help)   _print_help_from_caller "$caller"; exit 0;;
      *)           echo "Unknown arg: $1" >&2; echo >&2; _print_help_from_caller "$caller" >&2; exit 2;;
    esac
  done
  if [[ -z "$INPUT" || -z "$OUTPUT" ]]; then
    echo "Error: -i/--input and -o/--output are required." >&2
    echo >&2
    _print_help_from_caller "$caller" >&2
    exit 2
  fi
}

# strip_frontmatter <file>
#   Print markdown body with leading YAML frontmatter removed.
strip_frontmatter() {
  awk '
    BEGIN { in_fm=0; done=0 }
    NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
    in_fm && /^---[[:space:]]*$/ { in_fm=0; done=1; next }
    in_fm { next }
    { print }
  ' "$1"
}

# extract_field <file> <key>
#   Print first matching scalar frontmatter field, stripped of surrounding quotes.
#   Returns empty string if not present.
extract_field() {
  local file="$1" key="$2"
  awk -v key="$key" '
    BEGIN { in_fm=0 }
    NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
    in_fm && /^---[[:space:]]*$/ { exit }
    in_fm {
      pat = "^[[:space:]]*" key "[[:space:]]*:[[:space:]]*"
      if ($0 ~ pat) {
        sub(pat, "")
        sub(/[[:space:]]*$/, "")
        gsub(/^"|"$/, "")
        gsub(/^'\''|'\''$/, "")
        print; exit
      }
    }
  ' "$file"
}

# rewrite_skill_frontmatter <file> [drop=key | rename=old:new ...]
#   Print the file to stdout with frontmatter rewrites applied. Body is
#   preserved verbatim. Space-separated ops; keys are matched after trimming
#   whitespace on both sides of ":".
rewrite_skill_frontmatter() {
  local file="$1"; shift
  local ops="${*:-}"
  awk -v ops="$ops" '
    function get_key(line,   p, k) {
      p = index(line, ":")
      if (p == 0) return ""
      k = substr(line, 1, p-1)
      sub(/^[[:space:]]+/, "", k)
      sub(/[[:space:]]+$/, "", k)
      return k
    }
    BEGIN {
      n = split(ops, a, " ")
      for (i = 1; i <= n; i++) {
        if (a[i] == "") continue
        if (substr(a[i], 1, 5) == "drop=") {
          drops[substr(a[i], 6)] = 1
        } else if (substr(a[i], 1, 7) == "rename=") {
          s = substr(a[i], 8)
          sep = index(s, ":")
          if (sep > 0) renames[substr(s, 1, sep-1)] = substr(s, sep+1)
        }
      }
      in_fm = 0
    }
    NR==1 && /^---[[:space:]]*$/ { in_fm=1; print; next }
    in_fm && /^---[[:space:]]*$/ { in_fm=0; print; next }
    in_fm {
      k = get_key($0)
      if (k != "" && (k in drops)) next
      if (k != "" && (k in renames)) {
        p = index($0, ":")
        print renames[k] substr($0, p)
        next
      }
      print; next
    }
    { print }
  ' "$file"
}

# apply_skill_rewrite <skill_dir> [drop=key | rename=old:new ...]
#   In-place rewrite of <skill_dir>/SKILL.md. No-op when no SKILL.md exists.
apply_skill_rewrite() {
  local dir="$1"; shift
  local f="$dir/SKILL.md"
  [[ -f "$f" ]] || return 0
  local tmp="$f.tmp"
  rewrite_skill_frontmatter "$f" "$@" > "$tmp"
  mv "$tmp" "$f"
}

# insert_fm_line <file> <line>
#   Insert <line> immediately before the closing '---' of the YAML frontmatter.
#   No-op if the file has no frontmatter.
insert_fm_line() {
  local f="$1" line="$2"
  local tmp="$f.tmp"
  awk -v line="$line" '
    BEGIN { in_fm=0; inserted=0 }
    NR==1 && /^---[[:space:]]*$/ { in_fm=1; print; next }
    in_fm && /^---[[:space:]]*$/ {
      if (!inserted) { print line; inserted=1 }
      in_fm=0; print; next
    }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

# mcp_csv_to_yaml_flow_list <csv>
#   "a, b, c" -> "[a, b, c]". Used for Claude `mcpServers:`.
mcp_csv_to_yaml_flow_list() {
  local csv="$1"
  local -a items=()
  local item IFS=','
  for item in $csv; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [[ -n "$item" ]] && items+=("$item")
  done
  local joined="" i
  for i in "${items[@]+"${items[@]}"}"; do
    joined+="$i, "
  done
  echo "[${joined%, }]"
}

# mcp_csv_to_copilot_tools_list <csv>
#   "a, b" -> '["a/*", "b/*"]'. Used for Copilot agent `tools:`.
mcp_csv_to_copilot_tools_list() {
  local csv="$1"
  local -a items=()
  local item IFS=','
  for item in $csv; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [[ -n "$item" ]] && items+=("\"$item/*\"")
  done
  local joined="" i
  for i in "${items[@]+"${items[@]}"}"; do
    joined+="$i, "
  done
  echo "[${joined%, }]"
}

# sync_items <src_dir> <file|dir> <handler_fn>
#   Iterates items (top-level files or subdirectories) under src_dir.
#   file mode: picks *.md and uses the basename without .md (README.md is ignored).
#   dir mode:  picks every immediate subdirectory.
#   Respects $ITEMS (comma-separated) if set; otherwise uses everything.
#   Calls: handler_fn "<name>" "<src_path>"
sync_items() {
  local src_dir="$1" kind="$2" handler="$3"
  if [[ ! -d "$src_dir" ]]; then
    echo "No source dir: $src_dir" >&2; exit 1
  fi

  shopt -s nullglob
  local -a all=()
  if [[ "$kind" == "dir" ]]; then
    local d
    for d in "$src_dir"/*/; do
      all+=("$(basename "$d")")
    done
  else
    local f base
    for f in "$src_dir"/*.md; do
      base="$(basename "$f" .md)"
      [[ "$base" == "README" ]] && continue
      all+=("$base")
    done
  fi

  local -a selected=()
  if [[ -n "$ITEMS" ]]; then
    local -a raw=()
    IFS=',' read -r -a raw <<< "$ITEMS"
    local item trimmed
    for item in "${raw[@]}"; do
      # Strip leading whitespace (remove from start up to first non-space char),
      # then strip trailing whitespace (remove from last non-space char to end).
      trimmed="${item#"${item%%[![:space:]]*}"}"
      trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
      [[ -n "$trimmed" ]] && selected+=("$trimmed")
    done
  else
    selected=("${all[@]+"${all[@]}"}")
  fi

  if [[ ${#selected[@]} -eq 0 ]]; then
    echo "No items found in $src_dir"
    return 0
  fi

  local name src
  for name in "${selected[@]}"; do
    if [[ "$kind" == "dir" ]]; then
      src="$src_dir/$name"
      if [[ ! -d "$src" ]]; then
        echo "skip: $name (not a directory at $src)" >&2; continue
      fi
    else
      src="$src_dir/$name.md"
      if [[ ! -f "$src" ]]; then
        echo "skip: $name (not a file at $src)" >&2; continue
      fi
    fi
    "$handler" "$name" "$src"
  done
}
