#!/usr/bin/env bats
# Tests for install/install.sh's cyncia.conf management:
#   * creates the file with defaults when it is missing,
#   * leaves an existing file alone (preserved verbatim) on re-install,
#   * adds new schema properties (default yes when no TTY),
#   * removes obsolete properties only when the user opts in (default no
#     when no TTY).

load 'test_helper'

INSTALL_SH="${REPO_ROOT}/install/install.sh"

setup() {
  TEST_HOME="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_conf.XXXXXX")"
  FAKE_BIN="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_conf_bin.XXXXXX")"
  TAR_SRC="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_conf_tar.XXXXXX")"
  cat > "$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
url=""
for arg in "$@"; do url="$arg"; done
case "$url" in
  *"/archive/"*) exec cat "$FAKE_TARBALL" ;;
  *) exit 22 ;;
esac
EOF
  chmod +x "$FAKE_BIN/curl"
  export PATH="$FAKE_BIN:$PATH"

  # Build a minimal but valid snapshot.
  local stage="$TAR_SRC/stage"
  mkdir -p "$stage/cyncia-main"
  cp -R "${REPO_ROOT}/scripts" "$stage/cyncia-main/scripts"
  mkdir -p "$stage/cyncia-main/skills" "$stage/cyncia-main/examples"
  echo "# example" > "$stage/cyncia-main/examples/AGENTS.md"
  cat > "$stage/cyncia-main/README.md" <<'EOF'
# cyncia
## After installing
1. ok
## Usage
later
EOF
  echo "# full" > "$stage/cyncia-main/cyncia.md"
  ( cd "$stage" && tar -czf "$TEST_HOME/snap.tgz" cyncia-main )
  export FAKE_TARBALL="$TEST_HOME/snap.tgz"
}

teardown() {
  [[ -n "${TEST_HOME:-}" && -d "$TEST_HOME" ]] && rm -rf "$TEST_HOME"
  [[ -n "${FAKE_BIN:-}"  && -d "$FAKE_BIN"  ]] && rm -rf "$FAKE_BIN"
  [[ -n "${TAR_SRC:-}"   && -d "$TAR_SRC"   ]] && rm -rf "$TAR_SRC"
}

run_install() {
  cd "$TEST_HOME"
  run env CYNCIA_REPO="" CYNCIA_REF="" bash "$INSTALL_SH" "$@"
}

@test "install: creates .cyncia/cyncia.conf with default claude_rules_mode" {
  run_install --no-bootstrap
  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/.cyncia/cyncia.conf" ]
  grep -Eq '^claude_rules_mode:[[:space:]]*claude-md[[:space:]]*$' \
    "$TEST_HOME/.cyncia/cyncia.conf"
  [[ "$output" == *"Creating"* ]]
  [[ "$output" == *"cyncia.conf"* ]]
}

@test "install: preserves existing cyncia.conf on re-install" {
  run_install --no-bootstrap
  [ "$status" -eq 0 ]

  # User edits the value (portable in-place edit, works on macOS/BSD sed).
  awk '/^claude_rules_mode:/ { print "claude_rules_mode: rule-files"; next } { print }' \
    "$TEST_HOME/.cyncia/cyncia.conf" > "$TEST_HOME/.cyncia/cyncia.conf.tmp"
  mv "$TEST_HOME/.cyncia/cyncia.conf.tmp" "$TEST_HOME/.cyncia/cyncia.conf"
  cp "$TEST_HOME/.cyncia/cyncia.conf" "$TEST_HOME/conf.before"

  run_install --no-bootstrap
  [ "$status" -eq 0 ]
  diff -u "$TEST_HOME/conf.before" "$TEST_HOME/.cyncia/cyncia.conf"
  [[ "$output" == *"Keeping existing"* ]]
}

@test "install: adds a missing schema property (default yes via --bootstrap)" {
  # Pre-create a config that lacks every schema property.
  mkdir -p "$TEST_HOME/.cyncia"
  cat > "$TEST_HOME/.cyncia/cyncia.conf" <<'EOF'
# user config (intentionally empty)
EOF

  run_install --bootstrap
  [ "$status" -eq 0 ]
  grep -Eq '^claude_rules_mode:[[:space:]]*claude-md' \
    "$TEST_HOME/.cyncia/cyncia.conf"
  [[ "$output" == *"New cyncia.conf property"* ]]
  [[ "$output" == *"Add"* ]]
  [[ "$output" == *"-> yes"* ]]
}

@test "install: --no-bootstrap does NOT add missing schema property" {
  mkdir -p "$TEST_HOME/.cyncia"
  cat > "$TEST_HOME/.cyncia/cyncia.conf" <<'EOF'
# user config (intentionally empty)
EOF

  run_install --no-bootstrap
  [ "$status" -eq 0 ]
  ! grep -q '^claude_rules_mode:' "$TEST_HOME/.cyncia/cyncia.conf"
  [[ "$output" == *"-> no"* ]]
}

@test "install: prompts to remove unsupported property; --no-bootstrap keeps it" {
  mkdir -p "$TEST_HOME/.cyncia"
  cat > "$TEST_HOME/.cyncia/cyncia.conf" <<'EOF'
claude_rules_mode: claude-md
deprecated_option: hello
EOF

  run_install --no-bootstrap
  [ "$status" -eq 0 ]
  [[ "$output" == *"no longer supported"* ]]
  [[ "$output" == *"deprecated_option"* ]]
  # Default for removal is NO, so it must still be there.
  grep -q '^deprecated_option:' "$TEST_HOME/.cyncia/cyncia.conf"
}

@test "install: --bootstrap removes unsupported property" {
  mkdir -p "$TEST_HOME/.cyncia"
  cat > "$TEST_HOME/.cyncia/cyncia.conf" <<'EOF'
claude_rules_mode: claude-md
deprecated_option: hello
EOF

  run_install --bootstrap
  [ "$status" -eq 0 ]
  ! grep -q '^deprecated_option:' "$TEST_HOME/.cyncia/cyncia.conf"
  grep -q '^claude_rules_mode:' "$TEST_HOME/.cyncia/cyncia.conf"
}
