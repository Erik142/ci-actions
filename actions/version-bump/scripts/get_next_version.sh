#!/usr/bin/env bash
#
# Prints the next version (X.Y.Z, no leading "v") from Conventional Commits since the
# latest vX.Y.Z tag reachable from HEAD in the git repository of the current directory.
#
#   any "type!: ..." or a "BREAKING CHANGE: ..." /
#   "BREAKING-CHANGE: ..." footer                          -> major
#   "feat: ..." / "feat(scope): ..."                       -> minor
#   anything else                                          -> patch
#   merge commits                                          -> ignored (their commits count)
#   no commits since the latest tag                        -> the tag's version, unchanged
#   "revert: ..."                                          -> patch (a BREAKING CHANGE footer still gives major)
#   no vX.Y.Z tag reachable from HEAD                      -> bump from v0.0.0
# Rules follow https://www.conventionalcommits.org/en/v1.0.0/ and https://semver.org/ (2.0.0).
#
# Only tags matching vX.Y.Z exactly count; others (v1.2, v1.2.3-rc1, latest) are ignored.
# Requires full history and tags: a shallow clone is rejected (fetch-depth: 0 in CI).
# Usage: get_next_version.sh [-v]   (-v logs the decisions to stderr)

set -euo pipefail

verbose=n
while [ "$#" -gt 0 ]; do
  case "$1" in
    -v | --verbose) verbose=y ;;
    *)
      echo "usage: $0 [-v]" >&2
      exit 2
      ;;
  esac
  shift
done

log() {
  if [ "$verbose" = y ]; then
    echo "$*" >&2
  fi
}

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "error: not a git repository: $PWD" >&2
  exit 1
fi

if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
  echo "error: shallow clone; tags and history are incomplete (use fetch-depth: 0)" >&2
  exit 1
fi

# Newest vX.Y.Z tag by version order that HEAD contains (so a tag on another branch
# does not count). "|| true": no match is not an error here.
latest_tag="$(git tag -l 'v*' --merged HEAD --sort=-v:refname \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sed -n '1p' || true)"

if [ -n "$latest_tag" ]; then
  range="${latest_tag}..HEAD"
  base="${latest_tag#v}"
else
  range="HEAD"
  base="0.0.0"
fi
log "latest tag: ${latest_tag:-<none>}, range: ${range}"

# Merge commits carry no type of their own; the commits they bring in are counted.
commits="$(git rev-list --no-merges "$range")"
if [ -z "$commits" ] && [ -n "$latest_tag" ]; then
  log "no commits since ${latest_tag}"
  echo "$base"
  exit 0
fi

# Subjects are matched case-insensitively (spec: types are not case-sensitive).
subjects="$(git log --no-merges --format='%s' "$range")"

# Footers: the footer section is the last paragraph of each commit body (the spec puts
# footers one blank line after the body). Case-sensitive (spec: BREAKING CHANGE is uppercase).
footers="$(git log --no-merges --format='%H' "$range" | while read -r sha; do
  git show -s --format='%b' "$sha" | awk 'BEGIN { RS = "" } END { print }'
done)"

is_major() {
  # Any type with "!" before the colon: "feat!: ...", "fix(api)!: ...", "chore!: ...".
  grep -Eq '^[[:alpha:]]+(\([^()]+\))?!: .+' <<< "$subjects" \
    || grep -Eq '^BREAKING[ -]CHANGE(: .+| #.+)' <<< "$footers"
}

is_minor() {
  # A "!" commit is already handled as major above.
  grep -Eiq '^feat(\([^()]+\))?: .+' <<< "$subjects"
}

IFS=. read -r major minor patch <<< "$base"

if is_major; then
  log "bump: major"
  major=$((major + 1))
  minor=0
  patch=0
elif is_minor; then
  log "bump: minor"
  minor=$((minor + 1))
  patch=0
else
  log "bump: patch"
  patch=$((patch + 1))
fi

echo "${major}.${minor}.${patch}"
