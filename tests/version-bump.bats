#!/usr/bin/env bats

# Bump-rule tests for actions/version-bump/scripts/get_next_version.sh.
# Each test builds a throwaway git repo, runs the script from its root
# (the script reads git state from the current directory), and checks
# the printed version.

SCRIPT_SRC="${BATS_TEST_DIRNAME}/../actions/version-bump/scripts/get_next_version.sh"

setup() {
  REPO="$(mktemp -d)"
  cd "$REPO" || return 1
  git init -q -b main
  git config user.email "test@example.invalid"
  git config user.name "test"
}

teardown() {
  cd / || true
  rm -rf "$REPO"
}

# commit SUBJECT [BODY]
commit() {
  git commit -q --allow-empty -m "$1" ${2:+-m "$2"}
}

next_version() {
  run "$SCRIPT_SRC"
  [ "$status" -eq 0 ]
  echo "$output"
}

@test "feat subject bumps minor" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "feat: add widget"
  [ "$(next_version)" = "1.3.0" ]
}

@test "BREAKING CHANGE footer line bumps major" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "fix: rework api" "Details here.

BREAKING CHANGE: api renamed"
  [ "$(next_version)" = "2.0.0" ]
}

@test "chore subject bumps patch" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "chore: update deps"
  [ "$(next_version)" = "1.2.4" ]
}

@test "fix subject bumps patch" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "fix: handle empty input"
  [ "$(next_version)" = "1.2.4" ]
}

@test "docs subject bumps patch" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "docs: fix readme typo"
  [ "$(next_version)" = "1.2.4" ]
}

@test "release subject is no longer a major trigger" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "release: cut 2.0"
  [ "$(next_version)" = "1.2.4" ]
}

@test "body line starting with feat does not bump minor" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "fix: tidy logging" "feat flag was removed"
  [ "$(next_version)" = "1.2.4" ]
}

@test "no previous tag starts from v0.0.0 (patch)" {
  commit "chore: bootstrap"
  [ "$(next_version)" = "0.0.1" ]
}

@test "no previous tag starts from v0.0.0 (feat)" {
  commit "feat: first feature"
  [ "$(next_version)" = "0.1.0" ]
}

@test "non-semver tags are ignored (v1.2 is not 1.2.0)" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "fix: after release"
  git tag v1.2
  [ "$(next_version)" = "1.2.4" ]
}

@test "non-version tags are ignored" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "fix: after release"
  git tag latest
  [ "$(next_version)" = "1.2.4" ]
}

@test "prerelease tags are ignored" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "fix: after release"
  git tag v1.2.4-rc1
  [ "$(next_version)" = "1.2.4" ]
}

@test "no commits since latest tag prints that tag's version" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  [ "$(next_version)" = "1.2.3" ]
}

@test "subject prefixes are case-insensitive" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "Feat: add widget"
  [ "$(next_version)" = "1.3.0" ]
}

@test "MINOR VERSION is not a spec token and does not bump minor" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "fix: tweak" "MINOR VERSION"
  [ "$(next_version)" = "1.2.4" ]
}

@test "BREAKING-CHANGE footer synonym bumps major" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "fix: rework" "BREAKING-CHANGE: api renamed"
  [ "$(next_version)" = "2.0.0" ]
}

@test "BREAKING CHANGE footer needs colon and space" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "fix: rework" "BREAKING CHANGE"
  [ "$(next_version)" = "1.2.4" ]
}

@test "breaking change footer token is case-sensitive" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "fix: rework" "breaking change: api renamed"
  [ "$(next_version)" = "1.2.4" ]
}

@test "feat with ! bumps major, not minor" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "feat!: drop legacy api"
  [ "$(next_version)" = "2.0.0" ]
}

@test "feat with scope and ! bumps major" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "feat(api)!: drop legacy api"
  [ "$(next_version)" = "2.0.0" ]
}

@test "fix with ! bumps major" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "fix!: drop legacy api"
  [ "$(next_version)" = "2.0.0" ]
}

@test "other type with ! bumps major" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "chore(deps)!: require python 3.13"
  [ "$(next_version)" = "2.0.0" ]
}

@test "not inside a git repository fails" {
  NOREPO="$(mktemp -d)"
  cd "$NOREPO" || return 1
  run "$SCRIPT_SRC"
  [ "$status" -ne 0 ]
  cd "$REPO" || return 1
  rm -rf "$NOREPO"
}

@test "unknown argument fails with usage" {
  run "$SCRIPT_SRC" --bogus
  [ "$status" -eq 2 ]
}

@test "tag on another branch (not reachable from HEAD) is ignored" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  git checkout -q -b hotfix
  git commit -q --allow-empty -m "fix: hotfix"
  git tag v2.0.0
  git checkout -q main
  commit "fix: after release"
  [ "$(next_version)" = "1.2.4" ]
}

@test "shallow clone is rejected" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "fix: after release"
  SHALLOW="$(mktemp -d)"
  git clone -q --depth 1 "file://$REPO" "$SHALLOW/clone"
  cd "$SHALLOW/clone" || return 1
  run "$SCRIPT_SRC"
  [ "$status" -ne 0 ]
  cd "$REPO" || return 1
  rm -rf "$SHALLOW"
}

@test "type without space after colon is not a feat" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "feat:add widget"
  [ "$(next_version)" = "1.2.4" ]
}

@test "empty scope is not a feat" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "feat(): add widget"
  [ "$(next_version)" = "1.2.4" ]
}

@test "BREAKING CHANGE that is not in the footer section does not count" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "fix: rework" "BREAKING CHANGE: api renamed

Then more prose follows the line above."
  [ "$(next_version)" = "1.2.4" ]
}

@test "merge commit only since tag prints that tag's version" {
  git commit -q --allow-empty -m "init"
  commit "fix: a"
  git tag v1.2.3
  MERGE="$(git commit-tree "$(git rev-parse HEAD^{tree})" -p HEAD -p HEAD~1 -m "Merge")"
  git update-ref HEAD "$MERGE"
  [ "$(next_version)" = "1.2.3" ]
}

@test "feat from a merged branch still counts" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  git checkout -q -b feature
  commit "feat: add widget"
  git checkout -q main
  git merge -q --no-ff -m "Merge branch 'feature'" feature
  [ "$(next_version)" = "1.3.0" ]
}

@test "revert commit is a patch bump" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "revert: feat: add widget" "This reverts commit abc1234."
  [ "$(next_version)" = "1.2.4" ]
}

@test "revert commit with BREAKING CHANGE footer bumps major" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "revert: feat!: add widget" "This reverts commit abc1234.

BREAKING CHANGE: removes the widget api again"
  [ "$(next_version)" = "2.0.0" ]
}

@test "action step writes the version to GITHUB_OUTPUT" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "feat: add widget"
  ACTION_YML="${BATS_TEST_DIRNAME}/../actions/version-bump/action.yml"
  STEP="$(${PYTHON:-python3} -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["runs"]["steps"][0]["run"])' "$ACTION_YML")"
  OUT="$(mktemp)"
  export GITHUB_ACTION_PATH="$(cd "$(dirname "$SCRIPT_SRC")/.." && pwd)"
  export GITHUB_OUTPUT="$OUT"
  export WORKING_DIRECTORY="."
  run bash -c "$STEP"
  unset GITHUB_ACTION_PATH GITHUB_OUTPUT WORKING_DIRECTORY
  [ "$status" -eq 0 ]
  grep -qx 'version=1.3.0' "$OUT"
  grep -qx 'tag=v1.3.0' "$OUT"
  rm -f "$OUT"
}

@test "working-directory input selects a subdirectory of the repository" {
  git commit -q --allow-empty -m "init"
  git tag v1.2.3
  commit "feat: add widget"
  mkdir sub
  ACTION_YML="${BATS_TEST_DIRNAME}/../actions/version-bump/action.yml"
  STEP="$(${PYTHON:-python3} -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["runs"]["steps"][0]["run"])' "$ACTION_YML")"
  OUT="$(mktemp)"
  export GITHUB_ACTION_PATH="$(cd "$(dirname "$SCRIPT_SRC")/.." && pwd)"
  export GITHUB_OUTPUT="$OUT"
  export WORKING_DIRECTORY="sub"
  run bash -c "$STEP"
  unset GITHUB_ACTION_PATH GITHUB_OUTPUT WORKING_DIRECTORY
  [ "$status" -eq 0 ]
  grep -qx 'version=1.3.0' "$OUT"
  rm -f "$OUT"
}
