#!/usr/bin/env bats
# Tests for install/install.sh.
#
# We don't reach the network: a fake `curl` is placed first on PATH that
# emits a tarball assembled from a fixture tree under the test temp dir.
# Required env vars per test:
#   FAKE_TARBALL  - absolute path to a .tar.gz the fake curl will cat back.

load 'test_helper'

INSTALL_SH="${REPO_ROOT}/install/install.sh"

setup() {
  TEST_HOME="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_install.XXXXXX")"
  FAKE_BIN="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_install_bin.XXXXXX")"
  TAR_SRC="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/aisync_install_tar.XXXXXX")"
  cat > "$FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
# Fake curl: ignores flags, dispatches by URL (assumed to be the last arg).
#   archive tarballs    -> $FAKE_TARBALL
#   /commits/<ref>      -> $FAKE_COMMIT_JSON (or fail if unset)
#   /tags*              -> $FAKE_TAGS_JSON   (or fail if unset)
#   anything else       -> exit 22
url=""
for arg in "$@"; do url="$arg"; done
case "$url" in
  *"/archive/"*)
    exec cat "$FAKE_TARBALL" ;;
  *"api.github.com/repos/"*"/commits/"*)
    if [[ -n "${FAKE_COMMIT_JSON:-}" && -f "$FAKE_COMMIT_JSON" ]]; then
      exec cat "$FAKE_COMMIT_JSON"
    fi
    exit 22 ;;
  *"api.github.com/repos/"*"/tags"*)
    if [[ -n "${FAKE_TAGS_JSON:-}" && -f "$FAKE_TAGS_JSON" ]]; then
      exec cat "$FAKE_TAGS_JSON"
    fi
    exit 22 ;;
  *)
    echo "fake curl: unhandled URL: $url" >&2
    exit 22 ;;
esac
EOF
  chmod +x "$FAKE_BIN/curl"
  export PATH="$FAKE_BIN:$PATH"
  unset FAKE_COMMIT_JSON FAKE_TAGS_JSON
}

teardown() {
  [[ -n "${TEST_HOME:-}"  && -d "$TEST_HOME"  ]] && rm -rf "$TEST_HOME"
  [[ -n "${FAKE_BIN:-}"   && -d "$FAKE_BIN"   ]] && rm -rf "$FAKE_BIN"
  [[ -n "${TAR_SRC:-}"    && -d "$TAR_SRC"    ]] && rm -rf "$TAR_SRC"
}

# Build a tarball whose top-level directory is "$1" (e.g. "cyncia-main")
# containing the required entries plus a marker file.
# Args: <prefix> <out_tarball_path> [extra-marker-text]
build_tarball() {
  local prefix="$1" out="$2" marker="${3:-marker-default}"
  local stage
  stage="$(mktemp -d "${TAR_SRC}/stage.XXXXXX")"
  mkdir -p \
    "$stage/$prefix/scripts" \
    "$stage/$prefix/skills/sample-skill" \
    "$stage/$prefix/examples"
  cp "${REPO_ROOT}/scripts/sync-all.sh" "$stage/$prefix/scripts/sync-all.sh"
  chmod +x "$stage/$prefix/scripts/sync-all.sh"
  cat > "$stage/$prefix/skills/sample-skill/SKILL.md" <<EOF
---
name: sample-skill
description: Sample skill for install tests.
---
$marker
EOF
  cat > "$stage/$prefix/examples/AGENTS.md" <<EOF
# Example AGENTS guidelines ($marker)
EOF
  cat > "$stage/$prefix/README.md" <<EOF
# cyncia ($marker)

## Dependencies

stuff.

## Install

other stuff.

## After installing

1. Step one ($marker).
2. Step two.

## Usage

later.
EOF
  cat > "$stage/$prefix/cyncia.md" <<EOF
# cyncia full ref ($marker)
EOF
  cat > "$stage/$prefix/LICENSE" <<EOF
MIT License ($marker)
EOF
  ( cd "$stage" && tar -czf "$out" "$prefix" )
  rm -rf "$stage"
}

run_install() {
  cd "$TEST_HOME"
  run env CYNCIA_REPO="" CYNCIA_REF="" bash "$INSTALL_SH" "$@"
}

@test "install: --help prints usage and exits 0" {
  cd "$TEST_HOME"
  run bash "$INSTALL_SH" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Install or update cyncia"* ]]
  [[ "$output" == *"--config-dir"* ]]
  [[ "$output" == *"--bootstrap"* ]]
  # Help reflects the yes-by-default behavior.
  [[ "$output" == *"default when there is no TTY"* ]]
}

@test "install: rejects unknown option" {
  cd "$TEST_HOME"
  run bash "$INSTALL_SH" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "install: --no-bootstrap creates source tree, fetches snapshot, skips skill copy and sync" {
  build_tarball "cyncia-main" "$TEST_HOME/snap.tgz" "RUN1"
  export FAKE_TARBALL="$TEST_HOME/snap.tgz"

  run_install --no-bootstrap

  [ "$status" -eq 0 ]

  # Source tree subdirs created.
  [ -d "$TEST_HOME/.agent-config/agents" ]
  [ -d "$TEST_HOME/.agent-config/skills" ]
  [ -d "$TEST_HOME/.agent-config/rules" ]
  [ -d "$TEST_HOME/.agent-config/mcp-servers" ]

  # Stub AGENTS.md written when missing.
  [ -f "$TEST_HOME/.agent-config/AGENTS.md" ]

  # Snapshot landed.
  [ -f "$TEST_HOME/.cyncia/scripts/sync-all.sh" ]
  [ -x "$TEST_HOME/.cyncia/scripts/sync-all.sh" ]
  [ -f "$TEST_HOME/.cyncia/skills/sample-skill/SKILL.md" ]
  [ -f "$TEST_HOME/.cyncia/examples/AGENTS.md" ]
  [ -f "$TEST_HOME/.cyncia/README.md" ]
  [ -f "$TEST_HOME/.cyncia/cyncia.md" ]
  [ -f "$TEST_HOME/.cyncia/LICENSE" ]

  # --no-bootstrap skipped both interactive steps.
  [ ! -d "$TEST_HOME/.agent-config/skills/sample-skill" ]
  [ ! -d "$TEST_HOME/.cursor" ]

  # 'After installing' section shown from README.
  [[ "$output" == *"After installing"* ]]
  [[ "$output" == *"Step one (RUN1)"* ]]
  # Body stops before the next section.
  [[ "$output" != *"later."* ]]

  # jq notice printed.
  [[ "$output" == *"jq"* ]]
  [[ "$output" == *"brew install jq"* ]]
}

@test "install: existing AGENTS.md is preserved" {
  build_tarball "cyncia-main" "$TEST_HOME/snap.tgz"
  export FAKE_TARBALL="$TEST_HOME/snap.tgz"

  mkdir -p "$TEST_HOME/.agent-config"
  echo "ORIGINAL CONTENT" > "$TEST_HOME/.agent-config/AGENTS.md"

  run_install --no-bootstrap

  [ "$status" -eq 0 ]
  grep -q "ORIGINAL CONTENT" "$TEST_HOME/.agent-config/AGENTS.md"
  [[ "$output" == *"keeping existing"* ]]
}

# Build a "real" snapshot by copying actual scripts/ + examples/ from the repo
# but with synthetic skills/ controlled by the test. Used when --bootstrap is
# exercised (so sync-all has all the per-tool scripts it needs).
build_real_tarball() {
  local out="$1" marker="${2:-marker}"
  local stage="$TAR_SRC/real_$marker"
  mkdir -p "$stage/cyncia-main/skills/sample-skill"
  cp -R "${REPO_ROOT}/scripts"  "$stage/cyncia-main/scripts"
  cp -R "${REPO_ROOT}/examples" "$stage/cyncia-main/examples"
  cat > "$stage/cyncia-main/skills/sample-skill/SKILL.md" <<EOF
---
name: sample-skill
description: Sample for install tests.
---
$marker
EOF
  cat > "$stage/cyncia-main/README.md" <<EOF
# cyncia
## After installing
1. $marker
## Usage
later
EOF
  echo "# full" > "$stage/cyncia-main/cyncia.md"
  echo "MIT License ($marker)" > "$stage/cyncia-main/LICENSE"
  ( cd "$stage" && tar -czf "$out" cyncia-main )
}

@test "install: --bootstrap copies new skills into config/skills" {
  build_real_tarball "$TEST_HOME/snap.tgz" "BOOT"
  export FAKE_TARBALL="$TEST_HOME/snap.tgz"

  run_install --bootstrap

  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/.agent-config/skills/sample-skill/SKILL.md" ]
  grep -q "BOOT" "$TEST_HOME/.agent-config/skills/sample-skill/SKILL.md"
}

@test "install: --bootstrap overwrites already-present skill with upstream" {
  build_real_tarball "$TEST_HOME/snap.tgz" "FRESH"
  export FAKE_TARBALL="$TEST_HOME/snap.tgz"

  mkdir -p "$TEST_HOME/.agent-config/skills/sample-skill"
  echo "STALE LOCAL CONTENT" > "$TEST_HOME/.agent-config/skills/sample-skill/SKILL.md"

  run_install --bootstrap

  [ "$status" -eq 0 ]
  ! grep -q "STALE LOCAL CONTENT" "$TEST_HOME/.agent-config/skills/sample-skill/SKILL.md"
  grep -q "FRESH" "$TEST_HOME/.agent-config/skills/sample-skill/SKILL.md"
  [[ "$output" == *"already present"* ]]
}

@test "install: --no-bootstrap leaves existing user skill untouched" {
  build_tarball "cyncia-main" "$TEST_HOME/snap.tgz" "FRESH"
  export FAKE_TARBALL="$TEST_HOME/snap.tgz"

  mkdir -p "$TEST_HOME/.agent-config/skills/sample-skill"
  echo "USER LOCAL CONTENT" > "$TEST_HOME/.agent-config/skills/sample-skill/SKILL.md"

  run_install --no-bootstrap

  [ "$status" -eq 0 ]
  grep -q "USER LOCAL CONTENT" "$TEST_HOME/.agent-config/skills/sample-skill/SKILL.md"
}

@test "install: re-running refreshes .cyncia/ and drops files removed upstream" {
  build_tarball "cyncia-main" "$TEST_HOME/snap1.tgz" "ONE"

  # First run.
  export FAKE_TARBALL="$TEST_HOME/snap1.tgz"
  run_install --no-bootstrap
  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/.cyncia/skills/sample-skill/SKILL.md" ]

  # Build a second tarball where the bundled skill has been renamed.
  local stage="$TAR_SRC/stage2"
  mkdir -p \
    "$stage/cyncia-main/scripts" \
    "$stage/cyncia-main/skills/renamed-skill" \
    "$stage/cyncia-main/examples"
  cp "${REPO_ROOT}/scripts/sync-all.sh" "$stage/cyncia-main/scripts/sync-all.sh"
  cat > "$stage/cyncia-main/skills/renamed-skill/SKILL.md" <<'EOF'
---
name: renamed-skill
description: Renamed.
---
RENAMED
EOF
  echo "# example" > "$stage/cyncia-main/examples/AGENTS.md"
  cat > "$stage/cyncia-main/README.md" <<'EOF'
# cyncia (TWO)
## After installing
1. Updated.
## Usage
later
EOF
  echo "# full" > "$stage/cyncia-main/cyncia.md"
  echo "# license" > "$stage/cyncia-main/LICENSE"
  ( cd "$stage" && tar -czf "$TEST_HOME/snap2.tgz" cyncia-main )

  export FAKE_TARBALL="$TEST_HOME/snap2.tgz"
  run_install --no-bootstrap
  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/.cyncia/skills/renamed-skill/SKILL.md" ]
  # The old skill must have been removed by the rm -rf before extraction.
  [ ! -d "$TEST_HOME/.cyncia/skills/sample-skill" ]
  [[ "$output" == *"Updating existing cyncia checkout"* ]]
}

@test "install: custom --config-dir and --cyncia-dir" {
  build_tarball "cyncia-main" "$TEST_HOME/snap.tgz"
  export FAKE_TARBALL="$TEST_HOME/snap.tgz"

  run_install --no-bootstrap --config-dir my-cfg --cyncia-dir vendor/cyn

  [ "$status" -eq 0 ]
  [ -d "$TEST_HOME/my-cfg/agents" ]
  [ -f "$TEST_HOME/my-cfg/AGENTS.md" ]
  [ -f "$TEST_HOME/vendor/cyn/scripts/sync-all.sh" ]
  [ -f "$TEST_HOME/vendor/cyn/examples/AGENTS.md" ]
  [ ! -d "$TEST_HOME/.cyncia" ]
  [ ! -d "$TEST_HOME/.agent-config" ]
}

@test "install: handles tarball with a v-stripped tag prefix" {
  # GitHub strips the leading 'v' from tag refs in the tarball top-level dir.
  build_tarball "cyncia-1.2.3" "$TEST_HOME/snap.tgz" "TAG"
  export FAKE_TARBALL="$TEST_HOME/snap.tgz"

  run_install --no-bootstrap --ref v1.2.3

  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/.cyncia/scripts/sync-all.sh" ]
  [ -f "$TEST_HOME/.cyncia/examples/AGENTS.md" ]
}

@test "install: errors if snapshot is missing required entry" {
  # Tarball without examples/.
  local stage="$TAR_SRC/bad"
  mkdir -p "$stage/cyncia-main/scripts" "$stage/cyncia-main/skills"
  cp "${REPO_ROOT}/scripts/sync-all.sh" "$stage/cyncia-main/scripts/sync-all.sh"
  echo "# r" > "$stage/cyncia-main/README.md"
  echo "# c" > "$stage/cyncia-main/cyncia.md"
  ( cd "$stage" && tar -czf "$TEST_HOME/bad.tgz" cyncia-main )
  export FAKE_TARBALL="$TEST_HOME/bad.tgz"

  run_install --no-bootstrap

  [ "$status" -ne 0 ]
  [[ "$output" == *"examples missing from snapshot"* ]]
}

@test "install: errors if snapshot is missing LICENSE" {
  # Tarball with every required entry except LICENSE.
  local stage="$TAR_SRC/nolicense"
  mkdir -p "$stage/cyncia-main/scripts" "$stage/cyncia-main/skills" \
           "$stage/cyncia-main/examples"
  cp "${REPO_ROOT}/scripts/sync-all.sh" "$stage/cyncia-main/scripts/sync-all.sh"
  echo "# example" > "$stage/cyncia-main/examples/AGENTS.md"
  echo "# r" > "$stage/cyncia-main/README.md"
  echo "# c" > "$stage/cyncia-main/cyncia.md"
  ( cd "$stage" && tar -czf "$TEST_HOME/nolicense.tgz" cyncia-main )
  export FAKE_TARBALL="$TEST_HOME/nolicense.tgz"

  run_install --no-bootstrap

  [ "$status" -ne 0 ]
  [[ "$output" == *"LICENSE missing from snapshot"* ]]
}

@test "install: --bootstrap runs sync-all and produces tool outputs" {
  # Use a real fixture-flavored snapshot so sync-all has something to sync.
  # The tarball must look like the real repo: scripts/, skills/, examples/.
  local stage="$TAR_SRC/real"
  mkdir -p "$stage/cyncia-main"
  # Mirror the actual repo's scripts and skills (these are what sync-all uses).
  cp -R "${REPO_ROOT}/scripts" "$stage/cyncia-main/scripts"
  cp -R "${REPO_ROOT}/skills"  "$stage/cyncia-main/skills"
  cp -R "${REPO_ROOT}/examples" "$stage/cyncia-main/examples"
  echo "# README ## After installing\n1. ok\n## Usage" > "$stage/cyncia-main/README.md"
  echo "# full" > "$stage/cyncia-main/cyncia.md"
  echo "# license" > "$stage/cyncia-main/LICENSE"
  ( cd "$stage" && tar -czf "$TEST_HOME/real.tgz" cyncia-main )
  export FAKE_TARBALL="$TEST_HOME/real.tgz"

  run_install --bootstrap

  [ "$status" -eq 0 ]
  # sync-all generated tool layouts somewhere under TEST_HOME.
  [ -f "$TEST_HOME/AGENTS.md" ] || [ -f "$TEST_HOME/CLAUDE.md" ] || [ -d "$TEST_HOME/.cursor" ]
}

@test "install: defaults to yes when no flag is given and there is no TTY" {
  command -v perl >/dev/null 2>&1 || skip "perl not available for setsid"
  build_real_tarball "$TEST_HOME/snap.tgz" "DEFY"
  export FAKE_TARBALL="$TEST_HOME/snap.tgz"

  cd "$TEST_HOME"
  # Detach from any controlling terminal via setsid so /dev/tty is unreadable;
  # this exercises install.sh's no-TTY branch which now defaults to "yes".
  run env CYNCIA_REPO="" CYNCIA_REF="" \
      perl -e 'use POSIX qw(setsid); setsid(); exec { $ARGV[0] } @ARGV' \
      bash "$INSTALL_SH"

  [ "$status" -eq 0 ]
  # Default-yes should have copied the bundled skill into config/skills/.
  [ -f "$TEST_HOME/.agent-config/skills/sample-skill/SKILL.md" ]
  grep -q "DEFY" "$TEST_HOME/.agent-config/skills/sample-skill/SKILL.md"
  # And the no-TTY branch should have announced the default explicitly.
  [[ "$output" == *"(no TTY)"* ]]
  [[ "$output" == *"-> yes"* ]]
  # sync-all also defaulted to running -> tool outputs exist.
  [ -f "$TEST_HOME/AGENTS.md" ] || [ -f "$TEST_HOME/CLAUDE.md" ] || [ -d "$TEST_HOME/.cursor" ]
}

# --- VERSION file ------------------------------------------------------------

@test "install: writes VERSION file with literal ref for non-main branch" {
  build_tarball "cyncia-feat" "$TEST_HOME/snap.tgz"
  export FAKE_TARBALL="$TEST_HOME/snap.tgz"

  run_install --no-bootstrap --ref my-feature-branch

  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/.cyncia/VERSION" ]
  run cat "$TEST_HOME/.cyncia/VERSION"
  [ "$output" = "my-feature-branch" ]
}

@test "install: writes VERSION file with tag name when --ref is a tag" {
  build_tarball "cyncia-1.2.3" "$TEST_HOME/snap.tgz"
  export FAKE_TARBALL="$TEST_HOME/snap.tgz"

  run_install --no-bootstrap --ref v1.2.3

  [ "$status" -eq 0 ]
  run cat "$TEST_HOME/.cyncia/VERSION"
  [ "$output" = "v1.2.3" ]
}

@test "install: VERSION falls back to 'main' when API is unreachable" {
  build_tarball "cyncia-main" "$TEST_HOME/snap.tgz"
  export FAKE_TARBALL="$TEST_HOME/snap.tgz"
  # FAKE_COMMIT_JSON / FAKE_TAGS_JSON unset -> fake curl returns nonzero.

  run_install --no-bootstrap

  [ "$status" -eq 0 ]
  run cat "$TEST_HOME/.cyncia/VERSION"
  [ "$output" = "main" ]
}

@test "install: VERSION falls back to 'main' when API has no matching tags" {
  build_tarball "cyncia-main" "$TEST_HOME/snap.tgz"
  export FAKE_TARBALL="$TEST_HOME/snap.tgz"

  cat > "$TEST_HOME/commit.json" <<'EOF'
{
  "sha": "deadbeefcafef00d1234567890abcdef00112233",
  "commit": { "tree": { "sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } }
}
EOF
  cat > "$TEST_HOME/tags.json" <<'EOF'
[
  { "name": "v0.1.0", "commit": { "sha": "1111111111111111111111111111111111111111" } },
  { "name": "v0.2.0", "commit": { "sha": "2222222222222222222222222222222222222222" } }
]
EOF
  export FAKE_COMMIT_JSON="$TEST_HOME/commit.json"
  export FAKE_TAGS_JSON="$TEST_HOME/tags.json"

  run_install --no-bootstrap

  [ "$status" -eq 0 ]
  run cat "$TEST_HOME/.cyncia/VERSION"
  [ "$output" = "main" ]
}

@test "install: VERSION lists tag(s) pointing at main HEAD" {
  build_tarball "cyncia-main" "$TEST_HOME/snap.tgz"
  export FAKE_TARBALL="$TEST_HOME/snap.tgz"

  cat > "$TEST_HOME/commit.json" <<'EOF'
{
  "sha": "deadbeefcafef00d1234567890abcdef00112233",
  "commit": { "tree": { "sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } }
}
EOF
  cat > "$TEST_HOME/tags.json" <<'EOF'
[
  { "name": "v0.9.0", "commit": { "sha": "1111111111111111111111111111111111111111" } },
  { "name": "v1.0.0", "commit": { "sha": "deadbeefcafef00d1234567890abcdef00112233" } },
  { "name": "latest", "commit": { "sha": "deadbeefcafef00d1234567890abcdef00112233" } }
]
EOF
  export FAKE_COMMIT_JSON="$TEST_HOME/commit.json"
  export FAKE_TAGS_JSON="$TEST_HOME/tags.json"

  run_install --no-bootstrap

  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/.cyncia/VERSION" ]
  grep -qx "v1.0.0" "$TEST_HOME/.cyncia/VERSION"
  grep -qx "latest" "$TEST_HOME/.cyncia/VERSION"
  ! grep -qx "v0.9.0" "$TEST_HOME/.cyncia/VERSION"
  ! grep -qx "main"   "$TEST_HOME/.cyncia/VERSION"
}

@test "install: VERSION is refreshed on re-run when ref changes" {
  build_tarball "cyncia-main"   "$TEST_HOME/snap1.tgz"
  build_tarball "cyncia-1.0.0"  "$TEST_HOME/snap2.tgz"

  export FAKE_TARBALL="$TEST_HOME/snap1.tgz"
  run_install --no-bootstrap --ref some-branch
  [ "$status" -eq 0 ]
  run cat "$TEST_HOME/.cyncia/VERSION"
  [ "$output" = "some-branch" ]

  export FAKE_TARBALL="$TEST_HOME/snap2.tgz"
  run_install --no-bootstrap --ref v1.0.0
  [ "$status" -eq 0 ]
  run cat "$TEST_HOME/.cyncia/VERSION"
  [ "$output" = "v1.0.0" ]
}
