#!/usr/bin/env bash
#
# .github/actions/derive-version/derive-version.sh
#
# Core, unit-testable logic behind the `derive-version` composite action
# (action.yml, T028). Computes an application's version from git ALONE —
# deterministic, no human input (contracts/version-derivation.md, FR-008,
# FR-010, US2). The composite action is a thin, injection-safe wrapper around
# this script (see action.yml's header for why the logic lives here), so the
# whole algorithm is provable with bats (tests/unit/test_version_derivation.bats
# T025, tests/unit/test_pre_1_0.bats T026) without a GitHub Actions runner.
#
# Algorithm (contracts/version-derivation.md):
#   tag = git describe --tags --match 'v[0-9]*' --long --dirty
#
#   | source state              | semver          | derivation   | is_prerelease |
#   | exactly tag v1.2.3        | 1.2.3           | exact-tag    | false         |
#   | 5 commits past v1.2.3     | 1.2.3-5-gABBREV | git-describe | true          |
#   | no tags yet               | 0.0.0-<n>-gSHA  | git-describe | true          |
#   | working tree dirty (CI)   | — FAIL the build (R1)                          |
#
#   - pre_1_0 = (MAJOR == 0)  => attach the compatibility disclaimer (R3, FR-011)
#   - is_prerelease = git-describe build OR a prerelease TAG (e.g. v1.0.0-rc1);
#     a clean 0.x tag stays is_prerelease=false so it remains releasable (US3
#     R1) — the 0.x signal is carried by pre_1_0, not is_prerelease.
#   - --version override: pins the identity to an EXISTING tag; no path lets a
#     human invent a number not anchored to a tag (R4, FR-010).
#
# Output:
#   - stdout: a parseable `DERIVE_VERSION_RESULT semver=.. commit_sha=.. ..`
#     line, and (only when pre_1_0) a `DERIVE_VERSION_DISCLAIMER: ..` line.
#   - When $GITHUB_OUTPUT is set: semver, commit_sha, derivation, is_prerelease,
#     pre_1_0, and disclaimer keys — so a release workflow (T035) grafts the
#     version + disclaimer into notes without re-deriving.
#
# Usage:
#   derive-version.sh [--repo <dir>] [--version <vX.Y.Z tag that exists>]
#
# Exit codes:
#   0  ok
#   1  build-fail — the working tree is dirty (R1); never publish a -dirty
#      version. A caller treats this like any other gate failure.
#   2  usage      — bad/missing command-line arguments.
#   3  config     — not a git work tree, or a --version override naming a tag
#                   that does not exist / is not a SemVer tag (R4).
#
# Dependencies: git only (no yq here — this operates on the repo, not on the
# governance YAML).

set -euo pipefail

readonly EXIT_OK=0
readonly EXIT_BUILD_FAIL=1
readonly EXIT_USAGE=2
readonly EXIT_CONFIG=3

# FR-011 / R3 — the pre-1.0 compatibility disclaimer. Single line (it becomes a
# GITHUB_OUTPUT value and a release-notes fragment). MUST contain "compatibility".
readonly DISCLAIMER="This is a pre-1.0 (0.x) release: the public API is unstable and backward compatibility is not guaranteed between releases (a breaking change may ship without a major-version bump)."

usage() {
  cat >&2 <<'USAGE'
Usage: derive-version.sh [--repo <dir>] [--version <tag>]

  --repo     Path to the git repository to derive from. Optional; default: .
  --version  Optional override: pin the version to an EXISTING SemVer tag
             (e.g. v1.2.3). Rejected if the tag does not exist (R4). No path
             lets a human supply a number that is not anchored to a tag.
USAGE
}

repo="."
override=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      if [ "$#" -lt 2 ]; then
        echo "::error::derive-version: --repo requires a value." >&2
        usage
        exit "${EXIT_USAGE}"
      fi
      repo="${2:-}"
      shift 2
      ;;
    --version)
      if [ "$#" -lt 2 ]; then
        echo "::error::derive-version: --version requires a value." >&2
        usage
        exit "${EXIT_USAGE}"
      fi
      override="${2:-}"
      shift 2
      ;;
    -h | --help)
      usage
      exit "${EXIT_OK}"
      ;;
    *)
      echo "::error::derive-version: unknown argument '$1'." >&2
      usage
      exit "${EXIT_USAGE}"
      ;;
  esac
done

if [ -z "${repo}" ]; then
  repo="."
fi

# The repo must be a git work tree; a non-git directory is a hard config error,
# never a silent 0.0.0 (that would let an un-versioned build masquerade as a
# release candidate).
if ! git -C "${repo}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "::error::derive-version: '${repo}' is not a git work tree — cannot derive a version from git." >&2
  exit "${EXIT_CONFIG}"
fi

# strip_v <tag> — drop a leading 'v' to get the SemVer core (v1.2.3 -> 1.2.3).
strip_v() {
  printf '%s' "${1#v}"
}

# is_semver_tag <tag> — loose gate: must look like vMAJOR.MINOR.PATCH[...].
is_semver_tag() {
  [[ "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]
}

semver=""
derivation=""
commit_sha=""

if [ -n "${override}" ]; then
  # R4 — the override must be a real, existing SemVer tag.
  if ! is_semver_tag "${override}"; then
    echo "::error::derive-version: --version '${override}' is not a SemVer tag (expected vMAJOR.MINOR.PATCH)." >&2
    exit "${EXIT_CONFIG}"
  fi
  if ! git -C "${repo}" rev-parse -q --verify "refs/tags/${override}" >/dev/null 2>&1; then
    echo "::error::derive-version: --version '${override}' does not name an existing tag in '${repo}' — a version override MUST be anchored to a tag that exists (R4)." >&2
    exit "${EXIT_CONFIG}"
  fi
  semver="$(strip_v "${override}")"
  derivation="exact-tag"
  # Identity is the tag; the sha is the commit the tag points at.
  commit_sha="$(git -C "${repo}" rev-list -n 1 "${override}")"
else
  # No override: derive from HEAD. First fail closed on a dirty work tree —
  # a released artifact MUST build from a clean, exact state (R1). Untracked
  # files do not count as dirty (they match `git describe --dirty`'s view).
  if [ -n "$(git -C "${repo}" status --porcelain --untracked-files=no)" ]; then
    echo "::error::derive-version: working tree is dirty — refusing to derive a version. A dirty (-dirty) build must never be published (contracts/version-derivation.md R1)." >&2
    exit "${EXIT_BUILD_FAIL}"
  fi

  commit_sha="$(git -C "${repo}" rev-parse HEAD)"

  # `--long` always emits the `<tag>-<count>-g<abbrev>` form (even at count 0),
  # so exact-tag is detectable as count == 0 without a second describe call.
  if desc="$(git -C "${repo}" describe --tags --match 'v[0-9]*' --long 2>/dev/null)"; then
    # Parse from the right — the tag itself may contain '-' (e.g. v1.0.0-rc1).
    ghash="${desc##*-}"        # g<abbrev>
    rest="${desc%-*}"          # strip -g<abbrev>
    count="${rest##*-}"        # commits since tag
    tag="${rest%-*}"           # the matched tag (may contain '-')
    core="$(strip_v "${tag}")"
    if [ "${count}" = "0" ]; then
      semver="${core}"
      derivation="exact-tag"
    else
      semver="${core}-${count}-${ghash}"
      derivation="git-describe"
    fi
  else
    # No matching tag anywhere in history: anchor at 0.0.0 with the commit
    # depth and short sha (contracts/version-derivation.md "No tags yet").
    count="$(git -C "${repo}" rev-list --count HEAD)"
    short="$(git -C "${repo}" rev-parse --short HEAD)"
    semver="0.0.0-${count}-g${short}"
    derivation="git-describe"
  fi
fi

# MAJOR is the first numeric component of the SemVer core; pre_1_0 drives the
# compatibility disclaimer (R3, FR-011).
major="${semver%%.*}"
if [ "${major}" = "0" ]; then
  pre_1_0="true"
else
  pre_1_0="false"
fi

# is_prerelease: a git-describe (untagged-commit) build is always a prerelease;
# an exact tag is a prerelease only when the TAG carries a SemVer prerelease
# component (a '-' in the core, e.g. 1.0.0-rc1). A clean X.Y.Z (incl. 0.x) tag
# is a real release.
if [ "${derivation}" != "exact-tag" ]; then
  is_prerelease="true"
elif [[ "${semver}" == *-* ]]; then
  is_prerelease="true"
else
  is_prerelease="false"
fi

# --- emit -------------------------------------------------------------------

echo "DERIVE_VERSION_RESULT semver=${semver} commit_sha=${commit_sha} derivation=${derivation} is_prerelease=${is_prerelease} pre_1_0=${pre_1_0}"

disclaimer=""
if [ "${pre_1_0}" = "true" ]; then
  disclaimer="${DISCLAIMER}"
  echo "DERIVE_VERSION_DISCLAIMER: ${disclaimer}"
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "semver=${semver}"
    echo "commit_sha=${commit_sha}"
    echo "derivation=${derivation}"
    echo "is_prerelease=${is_prerelease}"
    echo "pre_1_0=${pre_1_0}"
    echo "disclaimer=${disclaimer}"
  } >> "${GITHUB_OUTPUT}"
fi

exit "${EXIT_OK}"
