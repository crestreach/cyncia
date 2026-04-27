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
#      <config-dir>/skills/ — interactive by default; --bootstrap says yes,
#      --no-bootstrap says no.
#   4. Optionally runs sync-all to generate the per-tool layouts — same
#      interactive / --bootstrap / --no-bootstrap rules.
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
  --bootstrap         Answer "yes" to every prompt: copy/update skills into
                      <config-dir>/skills and run sync-all afterwards.
  --no-bootstrap      Answer "no" to every prompt (useful for unattended runs
                      such as 'curl | bash' where there is no TTY).
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

for cmd in curl tar mktemp find; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: required command not found: $cmd" >&2
    exit 1
  fi
done

# --- helpers ----------------------------------------------------------------

# Read a yes/no answer. Honors --bootstrap / --no-bootstrap. Falls back to
# "no" when there is no controlling TTY (e.g. piped from curl) and the user
# did not pre-answer with a flag.
ask_yes_no() {
  local prompt="$1" default_no_msg="$2"
  case "$INTERACTIVE_MODE" in
    yes) echo "  [bootstrap] $prompt -> yes"; return 0 ;;
    no)  echo "  [no-bootstrap] $prompt -> no";  return 1 ;;
  esac
  if [[ ! -r /dev/tty ]]; then
    echo "  (no TTY) $prompt -> no ($default_no_msg)"
    return 1
  fi
  local reply
  read -r -p "  $prompt [y/N] " reply </dev/tty || reply=""
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
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
                "skip; copy manually later"; then
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
                "keep your local versions"; then
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
                "you can run it later"; then
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
