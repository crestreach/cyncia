#!/usr/bin/env bash
#
# generate-release-notes.sh — produce the GitHub-release variant of a Cyncia
# release-notes file.
#
# The committed notes file `rn/<version>.md` lives in `rn/`, so its links to repo
# files are written relative to that folder: `../cyncia.md`. Those
# `../` links resolve when the file is viewed inside the repo.
#
# On a GitHub *release page*, however, relative links are resolved against the
# repository ROOT at the release tag: GitHub rewrites a relative link `X` to
# `/<owner>/<repo>/blob/<tag>/X` (a leading `/` is stripped, the prefix is always
# `blob/<tag>/`, and `blob` auto-redirects to `tree` for directories). So a
# release-page link must be a bare repo-root-relative path, with no `../`, no
# leading `/`, and no `blob|tree/<tag>` of its own (adding any of those yields a
# double-prefixed 404).
#
# This script rebases each `../`-prefixed link from `rn/`-relative to root-relative
# by stripping the leading `../` (and the trailing `/` on directory links):
#
#   ../cyncia.md                              ->  cyncia.md
#   ../examples/skills/pirate-java-comments/  ->  examples/skills/pirate-java-comments
#
# GitHub then renders them as /<owner>/<repo>/blob/<tag>/<path>, pinned to the
# release's own tag. Absolute links (`https://...`) and in-page anchors (`#...`)
# are left untouched.
#
# The generated file is a throwaway: pass it to `gh release create|edit --notes-file`
# and then delete it. Only `rn/<version>.md` (and this script) are committed; the
# `rn/release/` output directory is gitignored.
#
# Usage:
#   rn/generate-release-notes.sh <version> [-o <output-path>]
#
#   <version>        e.g. v1.0.0  (reads rn/v1.0.0.md)
#   -o <output-path> where to write (default: rn/release/<version>-release.md;
#                    use `-` to write to stdout)
#
# On success the output path is printed to stdout (unless -o -), so callers can do:
#   gh release edit v1.0.0 --notes-file "$(rn/generate-release-notes.sh v1.0.0)"
#
set -euo pipefail

version=""
out=""

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output) out="${2:-}"; shift 2 ;;
    -h|--help)   sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)          echo "error: unknown option: $1" >&2; exit 2 ;;
    *)           if [ -z "$version" ]; then version="$1"; else echo "error: unexpected arg: $1" >&2; exit 2; fi; shift ;;
  esac
done

if [ -z "$version" ]; then
  echo "usage: $0 <version> [-o <output-path>]" >&2
  exit 2
fi

repo_root="$(git rev-parse --show-toplevel)"
src="$repo_root/rn/$version.md"
if [ ! -f "$src" ]; then
  echo "error: source notes not found: $src" >&2
  exit 1
fi

[ -n "$out" ] || out="$repo_root/rn/release/$version-release.md"

# Strip the leading `../` from each link target (rn/-relative -> root-relative).
# Directory links (target ends in `/`) also lose the trailing `/`. Run the
# directory rule first; the file rule then can't re-match (no more `../`).
rewrite() {
  perl -pe '
    s{\]\(\.\./([^)]*?)/\)}{]($1)}g;
    s{\]\(\.\./([^)]+)\)}{]($1)}g;
  ' "$src"
}

if [ "$out" = "-" ]; then
  rewrite
else
  mkdir -p "$(dirname "$out")"
  rewrite > "$out"
  printf '%s\n' "$out"
fi
