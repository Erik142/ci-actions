# ci-actions

Shared CI helper actions. Hosted on GitHub; usable from GitHub Actions and Forgejo Actions.

## Actions

### `actions/version-bump`

Computes the next semantic version from commits since the latest `v*` tag.

Bump rules (applied to commits since the latest tag, or the full history if there is none):

| Commit | Bump |
|---|---|
| any type with `!` before the colon: `feat!:`, `fix(api)!:`, `chore!:` | major |
| footer `BREAKING CHANGE: <description>` or `BREAKING-CHANGE: <description>` | major |
| subject `feat:` / `feat(scope):` | minor |
| `revert: ...` (reverting a fix or feature) | patch, or major if the revert has a `BREAKING CHANGE:` footer |
| anything else (`fix`, `chore`, `docs`, ...) | patch |

Merge commits are ignored; the commits they bring in are counted. A merge with no other commits since the tag leaves the version unchanged.

Rules follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) and [SemVer 2.0.0](https://semver.org/). Type names are case-insensitive; the footer token must be uppercase and followed by a colon and space. A body line that merely starts with `feat` has no effect.
With no `vX.Y.Z` tag, the version starts from `v0.0.0`. Only tags of the exact form `vX.Y.Z` count; `v1.2`, `latest` or `v1.2.4-rc1` are ignored. With no commits since the latest tag, the tag's version is printed unchanged.

**Inputs:**

| Name | Required | Default | Description |
|---|---|---|---|
| `working-directory` | no | `.` | Directory inside the repository whose git history is read. Use it for monorepos. |

**Outputs:**

| Name | Description |
|---|---|
| `version` | Next version without the leading `v`, e.g. `1.3.0`. |
| `tag` | Next version with the leading `v`, e.g. `v1.3.0`. |

The caller must check out the repository with its tags and history (`fetch-depth: 0` on `actions/checkout`). A shallow clone is rejected with an error. Only tags reachable from the checked-out commit count.

Example:

```yaml
steps:
  - uses: actions/checkout@v4
    with:
      fetch-depth: 0
  - id: version
    uses: Erik142/ci-actions/actions/version-bump@v1
  - run: echo "next version is ${{ steps.version.outputs.version }}"
```

From Forgejo Actions, use the full URL so the runner fetches from GitHub: `uses: https://github.com/Erik142/ci-actions/actions/version-bump@v1`. Not yet verified on the netcup runner.

## Versioning

- Releases are tagged `vX.Y.Z` (first release: `v1.0.0`).
- A moving `v1` tag points at the latest `v1.x.y` release. `.github/workflows/release.yml` runs the version script on `main`, creates `vX.Y.Z` and moves the major tag. It fails if the computed tag already exists. The first release, v1.0.0, is tagged by hand.
- Consumers pin either a tag (`@v1` to follow the major line, `@v1.0.0` for an exact release) or a full commit SHA.

## Requirements

- git 2.15 or newer on the runner (`rev-parse --is-shallow-repository`; `tag --merged` needs 2.7+).
- Full history and tags (`fetch-depth: 0`).

## Tests

Bump-rule tests use [bats](https://github.com/bats-core/bats-core):

```sh
bats tests/
```

Tests also include a wrapper check for `action.yml` and lint (shellcheck, YAML syntax). CI runs them on push and pull request from `.github/workflows/test.yml`.
