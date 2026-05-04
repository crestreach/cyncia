#!/usr/bin/env bash
# cyncia installer.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/crestreach/cyncia/main/install/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/crestreach/cyncia/main/install/install.sh \
#     | bash -s -- --bootstrap --ref main
#
# What it does:
#   1. Creates / updates the authoring source tree (default: .agent-config/)
#      with empty agents/, skills/, rules/, mcp-servers/ subdirectories and a
#      stub AGENTS.md (only if AGENTS.md does not already exist).
#   2. Downloads a snapshot of the cyncia repository (default ref: main) and
#      copies its scripts/, skills/, examples/, README.md, and cyncia.md into
#      the cyncia directory (default: .cyncia/). Existing scripts/, skills/,
#      and examples/ trees in that directory are replaced; README.md and
#      cyncia.md are overwritten.
#   3. Optionally copies (or updates) skills from .cyncia/skills/ into
#      <config-dir>/skills/ — interactive prompt defaults to "yes"; pass
#      --no-bootstrap to skip without asking. Without a TTY (e.g. 'curl |
#      bash') the answer is also "yes" by default.
#   4. Optionally runs sync-all to generate the per-tool layouts — same
#      yes-by-default / --no-bootstrap rules.
#   5. Prints jq install hints (jq is required only by the MCP sync step).
#   6. Prints the "After installing" section straight from the downloaded
#      README.md.

set -euo pipefail

REPO="${CYNCIA_REPO:-crestreach/cyncia}"
REF="${CYNCIA_REF:-main}"
CONFIG_DIR=".agent-config"
CYNCIA_DIR=".cyncia"
# tri-state: "ask" | "yes" | "no"
INTERACTIVE_MODE="ask"

usage() {
  cat <<'EOF'
Install or update cyncia in the current project.

Usage:
  install.sh [--config-dir PATH] [--cyncia-dir PATH] [--ref REF]
             [--repo OWNER/NAME] [--bootstrap | --no-bootstrap]

Options:
  --config-dir PATH   Authoring source tree           (default: .agent-config)
  --cyncia-dir PATH   Where the cyncia checkout lives (default: .cyncia)
  --ref REF           Git branch or tag to download   (default: main)
  --repo OWNER/NAME   GitHub repo to download from    (default: crestreach/cyncia)
  --bootstrap         Answer "yes" to every prompt without asking. This is
                      also the default when there is no TTY (e.g. piped from
                      curl); use --no-bootstrap to opt out in that case.
  --no-bootstrap      Answer "no" to every prompt: skip copying skills into
                      <config-dir>/skills and skip running sync-all.
  -h, --help          Show this help and exit.

Env overrides:
  CYNCIA_REPO, CYNCIA_REF
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-dir)    CONFIG_DIR="${2:?--config-dir requires a value}"; shift 2 ;;
    --cyncia-dir)    CYNCIA_DIR="${2:?--cyncia-dir requires a value}"; shift 2 ;;
    --ref)           REF="${2:?--ref requires a value}";               shift 2 ;;
    --repo)          REPO="${2:?--repo requires a value}";             shift 2 ;;
    --bootstrap)     INTERACTIVE_MODE="yes"; shift ;;
    --no-bootstrap)  INTERACTIVE_MODE="no";  shift ;;
    -h|--help)       usage; exit 0 ;;
    *) echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

for cmd in curl tar mktemp find awk; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: required command not found: $cmd" >&2
    exit 1
  fi
done

# --- helpers ----------------------------------------------------------------

# Read a yes/no answer. Honors --bootstrap / --no-bootstrap. Defaults to
# "yes" — both at the interactive prompt (empty reply means yes) and when
# there is no controlling TTY (e.g. 'curl | bash'), so the common case
# "install everything" works with zero typing. Use --no-bootstrap to opt out.
ask_yes_no() {
  local prompt="$1" default_yes_msg="$2"
  case "$INTERACTIVE_MODE" in
    yes) echo "  [bootstrap] $prompt -> yes"; return 0 ;;
    no)  echo "  [no-bootstrap] $prompt -> no";  return 1 ;;
  esac
  # Probe whether /dev/tty can actually be opened for reading. Just testing
  # `[ -r /dev/tty ]` is not enough on macOS — the file mode says "readable"
  # even from a session with no controlling terminal, where the open(2) call
  # would fail with ENXIO.
  if ! ( exec </dev/tty ) 2>/dev/null; then
    echo "  (no TTY) $prompt -> yes ($default_yes_msg)"
    return 0
  fi
  local reply
  read -r -p "  $prompt [Y/n] " reply </dev/tty || reply=""
  # Empty reply or anything starting with y/Y -> yes; only an explicit n/N -> no.
  [[ -z "$reply" || "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# --- 1. Authoring source tree ------------------------------------------------

echo "==> Preparing source tree at $CONFIG_DIR/"
mkdir -p \
  "$CONFIG_DIR" \
  "$CONFIG_DIR/agents" \
  "$CONFIG_DIR/skills" \
  "$CONFIG_DIR/rules" \
  "$CONFIG_DIR/mcp-servers"

if [[ ! -f "$CONFIG_DIR/AGENTS.md" ]]; then
  echo "    creating $CONFIG_DIR/AGENTS.md (stub)"
  cat > "$CONFIG_DIR/AGENTS.md" <<'EOF'
# Project guidelines

<!-- Authored by you; synced to AGENTS.md / CLAUDE.md / .github/copilot-instructions.md / .junie/AGENTS.md -->
EOF
else
  echo "    keeping existing $CONFIG_DIR/AGENTS.md"
fi

# --- 2. Download cyncia snapshot --------------------------------------------

CYNCIA_EXISTED="no"
if [[ -d "$CYNCIA_DIR/scripts" || -d "$CYNCIA_DIR/skills" ]]; then
  CYNCIA_EXISTED="yes"
  echo "==> Updating existing cyncia checkout at $CYNCIA_DIR/ ($REPO @ $REF)"
else
  echo "==> Fetching cyncia ($REPO @ $REF) into $CYNCIA_DIR/"
fi

TARBALL_URL="https://github.com/${REPO}/archive/${REF}.tar.gz"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! curl -fsSL "$TARBALL_URL" | tar -xz -C "$TMP"; then
  echo "error: failed to download or extract $TARBALL_URL" >&2
  exit 1
fi

# GitHub tarballs contain a single top-level directory; find it (the prefix
# may not be exactly "<repo>-<ref>" — e.g. tags drop a leading "v").
SRC="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -n1)"
if [[ -z "$SRC" ]]; then
  echo "error: extracted archive is empty" >&2
  exit 1
fi

for entry in scripts skills examples README.md cyncia.md; do
  if [[ ! -e "$SRC/$entry" ]]; then
    echo "error: $entry missing from snapshot $REPO@$REF" >&2
    exit 1
  fi
done

mkdir -p "$CYNCIA_DIR"
rm -rf "$CYNCIA_DIR/scripts" "$CYNCIA_DIR/skills" "$CYNCIA_DIR/examples"
cp -R "$SRC/scripts"  "$CYNCIA_DIR/scripts"
cp -R "$SRC/skills"   "$CYNCIA_DIR/skills"
cp -R "$SRC/examples" "$CYNCIA_DIR/examples"
cp    "$SRC/README.md" "$CYNCIA_DIR/README.md"
cp    "$SRC/cyncia.md" "$CYNCIA_DIR/cyncia.md"

# Re-assert exec bit on shell scripts (tar usually preserves this, but some
# transports — e.g. zip mirrors — strip it).
find "$CYNCIA_DIR/scripts" -type f -name '*.sh' -exec chmod +x {} +

if [[ "$CYNCIA_EXISTED" == "yes" ]]; then
  echo "    refreshed $CYNCIA_DIR/{scripts,skills,examples,README.md,cyncia.md}"
else
  echo "    wrote $CYNCIA_DIR/{scripts,skills,examples,README.md,cyncia.md}"
fi

# --- 2b. Record installed version -------------------------------------------
#
# Write $CYNCIA_DIR/VERSION with the ref that was installed. When the ref is
# the default branch ("main"), best-effort query the GitHub API for tags
# pointing at HEAD; if any are found, list those instead. The lookup is
# allowed to fail silently (offline / rate-limited / private repo): on any
# failure we fall back to the literal ref.

# Extract the first top-level "sha" string from a GitHub commit JSON payload.
# (GitHub returns the commit SHA as the first "sha" field; nested "sha"
# fields under "tree"/"parents"/"author" come later.)
extract_first_sha() {
  awk '
    match($0, /"sha"[[:space:]]*:[[:space:]]*"[0-9a-f]+"/) {
      s = substr($0, RSTART, RLENGTH)
      sub(/^"sha"[[:space:]]*:[[:space:]]*"/, "", s)
      sub(/"$/, "", s)
      print s
      exit
    }
  '
}

# Print tag names (one per line) whose commit.sha equals $1, parsed from the
# /repos/OWNER/NAME/tags JSON payload on stdin.
extract_tags_for_sha() {
  awk -v target="$1" '
    BEGIN { RS = "}" }
    {
      name = ""; commit_sha = ""
      if (match($0, /"name"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
        s = substr($0, RSTART, RLENGTH)
        sub(/^"name"[[:space:]]*:[[:space:]]*"/, "", s)
        sub(/"$/, "", s)
        name = s
      }
      if (match($0, /"sha"[[:space:]]*:[[:space:]]*"[0-9a-f]+"/)) {
        s = substr($0, RSTART, RLENGTH)
        sub(/^"sha"[[:space:]]*:[[:space:]]*"/, "", s)
        sub(/"$/, "", s)
        commit_sha = s
      }
      if (name != "" && commit_sha == target) print name
    }
  '
}

VERSION_TEXT="$REF"
if [[ "$REF" == "main" ]]; then
  api_sha="$(curl -fsSL -H 'Accept: application/vnd.github+json' \
              "https://api.github.com/repos/${REPO}/commits/${REF}" 2>/dev/null \
              | extract_first_sha 2>/dev/null || true)"
  if [[ -n "${api_sha:-}" ]]; then
    api_tags="$(curl -fsSL -H 'Accept: application/vnd.github+json' \
                  "https://api.github.com/repos/${REPO}/tags?per_page=100" 2>/dev/null \
                  | extract_tags_for_sha "$api_sha" 2>/dev/null || true)"
    if [[ -n "${api_tags:-}" ]]; then
      VERSION_TEXT="$api_tags"
    fi
  fi
fi
printf '%s\n' "$VERSION_TEXT" > "$CYNCIA_DIR/VERSION"
echo "    wrote $CYNCIA_DIR/VERSION:"
while IFS= read -r _line; do
  [[ -n "$_line" ]] && echo "      $_line"
done <<<"$VERSION_TEXT"

# --- 2c. cyncia.conf (project-level cyncia configuration) -------------------
#
# A tiny flat YAML file at $CYNCIA_DIR/cyncia.conf, used by the sync scripts.
# We carry the schema in the installer (so a newer installer knows about
# properties that older configs don't). Each entry is "key|default|description".
# The installer:
#   * creates the file from the schema when it is missing,
#   * leaves an existing file alone, but
#       - asks (default YES) before adding properties newly introduced in this
#         version of cyncia (i.e. in the schema but missing from the file),
#       - asks (default NO) before removing properties that are no longer in
#         the schema (i.e. in the file but missing from the schema).

CYNCIA_CONF_SCHEMA=(
  "claude-rules-mode|claude-md|How rules/<name>.md is emitted for Claude Code: 'claude-md' merges rule bodies into CLAUDE.md (default); 'rule-files' writes one file per rule to .claude/rules/<name>.md and imports them from CLAUDE.md via @-imports so Claude loads them with the same priority as CLAUDE.md."
  "codex-rules-mode|agents-override|How Codex Markdown rule guidance is handled: 'agents-override' merges AGENTS.md plus rules/*.md into AGENTS.override.md at the output root; 'ignore' does not emit Markdown rules for Codex."
  "codex-sync-mcp|true|Whether Codex MCP servers are synced into .codex/config.toml. When enabled, cyncia updates only the mcp_servers tables and preserves unrelated Codex config."
  "default-tools|cursor,claude,copilot,vscode,junie,codex|Comma-separated tool list used by sync-all when --tools / -Tools is omitted."
)

CONF_PATH="$CYNCIA_DIR/cyncia.conf"

# Lower-case ASCII fold without `${var,,}` (so we keep bash 3.2 portability,
# which macOS still ships).
_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Print 0/1 lines: 1 if the file already declares <key>, 0 otherwise.
# Tolerates leading whitespace, comments and surrounding quotes on the value.
_conf_has_key() {
  local file="$1" key="$2"
  awk -v key="$key" '
    BEGIN { found = 0 }
    {
      line = $0
      sub(/#.*$/, "", line)
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == "") next
      p = index(line, ":")
      if (p == 0) next
      k = substr(line, 1, p-1)
      sub(/[[:space:]]+$/, "", k)
      if (k == key) { found = 1; exit }
    }
    END { print found ? 1 : 0 }
  ' "$file"
}

# Print every key declared in the file (one per line, in source order).
_conf_keys() {
  local file="$1"
  awk '
    {
      line = $0
      sub(/#.*$/, "", line)
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == "") next
      p = index(line, ":")
      if (p == 0) next
      k = substr(line, 1, p-1)
      sub(/[[:space:]]+$/, "", k)
      if (k != "") print k
    }
  ' "$file"
}

# Append a default entry for <key> with description and value to the file.
_conf_append_default() {
  local file="$1" key="$2" default="$3" description="$4"
  {
    printf '\n'
    # Wrap long descriptions at ~76 chars, prefixing each line with "# ".
    printf '%s\n' "$description" | awk '
      {
        n = split($0, words, /[[:space:]]+/)
        line = "#"
        for (i = 1; i <= n; i++) {
          if (words[i] == "") continue
          tentative = line " " words[i]
          if (length(tentative) > 78 && line != "#") {
            print line
            line = "# " words[i]
          } else {
            line = (line == "#") ? "# " words[i] : line " " words[i]
          }
        }
        if (line != "#") print line
      }
    '
    printf '%s: %s\n' "$key" "$default"
  } >> "$file"
}

# Remove every line that declares <key>: ... (preserves blank lines and
# comments around it).
_conf_remove_key() {
  local file="$1" key="$2"
  local tmp="$file.tmp"
  awk -v key="$key" '
    {
      line = $0
      stripped = $0
      sub(/#.*$/, "", stripped)
      sub(/^[[:space:]]+/, "", stripped)
      sub(/[[:space:]]+$/, "", stripped)
      if (stripped == "") { print; next }
      p = index(stripped, ":")
      if (p == 0) { print; next }
      k = substr(stripped, 1, p-1)
      sub(/[[:space:]]+$/, "", k)
      if (k == key) next
      print line
    }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# ask_yes_no_default <prompt> <default-yes|default-no>
#   Like ask_yes_no, but with an explicit default for non-interactive mode.
ask_yes_no_default() {
  local prompt="$1" default="$2"
  case "$INTERACTIVE_MODE" in
    yes) echo "  [bootstrap] $prompt -> yes"; return 0 ;;
    no)  echo "  [no-bootstrap] $prompt -> no";  return 1 ;;
  esac
  if ! ( exec </dev/tty ) 2>/dev/null; then
    if [[ "$default" == "default-yes" ]]; then
      echo "  (no TTY) $prompt -> yes (default)"
      return 0
    else
      echo "  (no TTY) $prompt -> no (default)"
      return 1
    fi
  fi
  local reply hint
  if [[ "$default" == "default-yes" ]]; then hint="[Y/n]"; else hint="[y/N]"; fi
  read -r -p "  $prompt $hint " reply </dev/tty || reply=""
  if [[ "$default" == "default-yes" ]]; then
    [[ -z "$reply" || "$(_lower "$reply")" =~ ^y(es)?$ ]]
  else
    [[ "$(_lower "$reply")" =~ ^y(es)?$ ]]
  fi
}

if [[ ! -f "$CONF_PATH" ]]; then
  echo "==> Creating $CONF_PATH (defaults)"
  {
    printf '# cyncia configuration. See %s/README.md for details.\n' "$CYNCIA_DIR"
    printf '#\n'
    printf '# This file is read by the sync scripts at run time. The installer\n'
    printf '# leaves an existing file alone, prompts before adding new properties\n'
    printf '# introduced by future versions, and prompts before removing\n'
    printf '# properties that are no longer supported.\n'
  } > "$CONF_PATH"
  for entry in "${CYNCIA_CONF_SCHEMA[@]}"; do
    IFS='|' read -r _ck _cd _cdesc <<< "$entry"
    _conf_append_default "$CONF_PATH" "$_ck" "$_cd" "$_cdesc"
  done
  echo "    wrote $CONF_PATH"
else
  echo "==> Keeping existing $CONF_PATH (will reconcile against current schema)"

  # Pass 1: add properties that are in the schema but missing from the file.
  for entry in "${CYNCIA_CONF_SCHEMA[@]}"; do
    IFS='|' read -r _ck _cd _cdesc <<< "$entry"
    if [[ "$(_conf_has_key "$CONF_PATH" "$_ck")" == "0" ]]; then
      echo
      echo "  New cyncia.conf property in this version: $_ck (default: $_cd)"
      echo "    $_cdesc"
      if ask_yes_no_default \
           "Add '$_ck: $_cd' to $CONF_PATH?" default-yes; then
        _conf_append_default "$CONF_PATH" "$_ck" "$_cd" "$_cdesc"
        echo "    added $_ck=$_cd"
      else
        echo "    skipped $_ck (sync scripts will use the built-in default: $_cd)"
      fi
    fi
  done

  # Pass 2: remove properties present in the file but not in the schema.
  schema_keys=()
  for entry in "${CYNCIA_CONF_SCHEMA[@]}"; do
    IFS='|' read -r _ck _ _ <<< "$entry"
    schema_keys+=("$_ck")
  done
  while IFS= read -r existing_key; do
    [[ -z "$existing_key" ]] && continue
    in_schema="no"
    for sk in "${schema_keys[@]+"${schema_keys[@]}"}"; do
      if [[ "$sk" == "$existing_key" ]]; then in_schema="yes"; break; fi
    done
    if [[ "$in_schema" == "no" ]]; then
      echo
      echo "  Property in $CONF_PATH that is no longer supported by cyncia: $existing_key"
      if ask_yes_no_default \
           "Remove '$existing_key' from $CONF_PATH?" default-no; then
        _conf_remove_key "$CONF_PATH" "$existing_key"
        echo "    removed $existing_key"
      else
        echo "    kept $existing_key (sync scripts will ignore it)"
      fi
    fi
  done < <(_conf_keys "$CONF_PATH" | awk '!seen[$0]++')
fi

# --- 3. Skills bootstrap (copy / update <config-dir>/skills) -----------------

# Classify each skill in $CYNCIA_DIR/skills as "new" (not present in
# <config-dir>/skills) or "existing".
NEW_SKILLS=()
EXISTING_SKILLS=()
if [[ -d "$CYNCIA_DIR/skills" ]]; then
  for skill_path in "$CYNCIA_DIR/skills"/*/; do
    [[ -d "$skill_path" ]] || continue
    name="$(basename "$skill_path")"
    if [[ -d "$CONFIG_DIR/skills/$name" ]]; then
      EXISTING_SKILLS+=("$name")
    else
      NEW_SKILLS+=("$name")
    fi
  done
fi

copy_skill() {
  local name="$1"
  rm -rf "$CONFIG_DIR/skills/$name"
  cp -R "$CYNCIA_DIR/skills/$name" "$CONFIG_DIR/skills/$name"
}

if (( ${#NEW_SKILLS[@]} > 0 )); then
  echo
  echo "==> Skills available in $CYNCIA_DIR/skills/ but missing from $CONFIG_DIR/skills/:"
  for n in "${NEW_SKILLS[@]}"; do echo "      - $n"; done
  if ask_yes_no "Copy these skills into $CONFIG_DIR/skills/?" \
                "copy them"; then
    for n in "${NEW_SKILLS[@]}"; do
      copy_skill "$n"
      echo "    copied $n -> $CONFIG_DIR/skills/$n"
    done
  fi
fi

if (( ${#EXISTING_SKILLS[@]} > 0 )); then
  echo
  echo "==> Skills already present in $CONFIG_DIR/skills/ that also ship with cyncia:"
  for n in "${EXISTING_SKILLS[@]}"; do echo "      - $n"; done
  if ask_yes_no "Overwrite them with the upstream copies from $CYNCIA_DIR/skills/?" \
                "overwrite with upstream"; then
    for n in "${EXISTING_SKILLS[@]}"; do
      copy_skill "$n"
      echo "    updated $CONFIG_DIR/skills/$n"
    done
  fi
fi

# --- 4. Optionally run sync-all ---------------------------------------------

SYNC_SCRIPT="$CYNCIA_DIR/scripts/sync-all.sh"
if [[ -f "$SYNC_SCRIPT" ]]; then
  echo
  if ask_yes_no "Run $SYNC_SCRIPT -i $CONFIG_DIR -o . now?" \
                "running it now"; then
    bash "$SYNC_SCRIPT" -i "$CONFIG_DIR" -o "."
  fi
fi

# --- 5. jq notice ------------------------------------------------------------

cat <<'EOF'

==> jq

  jq 1.6+ is required ONLY by the MCP sync step (scripts/**/sync-mcp.sh and the
  MCP step of sync-all). If you do not author MCP servers under
  <source-root>/mcp-servers/, the step is skipped and jq is not needed.

  Install if needed:
    macOS:    brew install jq
    Debian:   sudo apt-get install jq
    Fedora:   sudo dnf install jq
    Arch:     sudo pacman -S jq
    Alpine:   apk add jq
    Windows:  winget install jqlang.jq    (or: choco install jq)

EOF

# --- 6. "After installing" section from README -------------------------------

if [[ -f "$CYNCIA_DIR/README.md" ]]; then
  echo "==> Next steps (from $CYNCIA_DIR/README.md § \"After installing\")"
  echo
  awk '
    /^## After installing[[:space:]]*$/ { in_section = 1; print; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$CYNCIA_DIR/README.md"
fi

echo
echo "Done."
