#!/usr/bin/env bats
#
# T025 (US2): bats unit test for the `derive-version` composite action's core
# logic (.github/actions/derive-version/derive-version.sh, T028). Asserts the
# script derives an application version from git ALONE — no human input — per
# every row of contracts/version-derivation.md (FR-008, FR-010):
#
#   | source state              | semver          | derivation   | is_prerelease |
#   | exactly tag v1.2.3        | 1.2.3           | exact-tag    | false         |
#   | 5 commits past v1.2.3     | 1.2.3-5-gABBREV | git-describe | true          |
#   | no tags yet               | 0.0.0-<n>-gSHA  | git-describe | true          |
#   | working tree dirty (CI)   | — FAIL the build (never publish a -dirty version, R1) |
#
# Plus the R4 rule that the optional `--version` override must itself be an
# existing tag (no path lets a human invent a number not anchored to a tag),
# and the -rc case from the data model (a prerelease TAG is is_prerelease=true
# even though it is an exact-tag build).
#
# Every fixture is a throwaway git repo built under $BATS_TEST_TMPDIR (unique
# per test), so this suite depends only on `git` — never on the surrounding
# repo's own history or on network access. commit_sha is asserted structurally
# (a 40-hex string), never as a fixed value, since a fresh repo's shas are not
# predictable without a fixed clock.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  DERIVE="${REPO_ROOT}/.github/actions/derive-version/derive-version.sh"
}

# --- fixture helpers --------------------------------------------------------

_init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email "tester@example.com"
  git -C "$dir" config user.name "Tester"
  git -C "$dir" config commit.gpgsign false
  # Global config sets tag.gpgsign=true; that turns a plain `git tag <name>`
  # into a signed annotated tag demanding a message. Force lightweight tags
  # so the fixtures stay hermetic (no signing key, no interactive prompt).
  git -C "$dir" config tag.gpgsign false
}

# _commit <dir> <msg> — an empty commit (history depth without file churn).
_commit() {
  git -C "$1" commit -q --allow-empty -m "$2"
}

# --- exact-tag --------------------------------------------------------------

@test "exact tag v1.2.3 -> semver 1.2.3, exact-tag, not prerelease" {
  repo="${BATS_TEST_TMPDIR}/exact"
  _init_repo "$repo"
  _commit "$repo" "c1"
  git -C "$repo" tag v1.2.3

  run "$DERIVE" --repo "$repo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"semver=1.2.3"* ]]
  [[ "$output" == *"derivation=exact-tag"* ]]
  [[ "$output" == *"is_prerelease=false"* ]]
  # commit_sha is the full 40-hex object id, not the short describe suffix.
  [[ "$output" =~ commit_sha=[0-9a-f]{40} ]]
}

# --- git-describe (commits past a tag) --------------------------------------

@test "5 commits past v1.2.3 -> semver 1.2.3-5-g<sha>, git-describe, prerelease" {
  repo="${BATS_TEST_TMPDIR}/describe"
  _init_repo "$repo"
  _commit "$repo" "c1"
  git -C "$repo" tag v1.2.3
  for i in 1 2 3 4 5; do _commit "$repo" "past-$i"; done

  run "$DERIVE" --repo "$repo"
  [ "$status" -eq 0 ]
  [[ "$output" =~ semver=1\.2\.3-5-g[0-9a-f]+ ]]
  [[ "$output" == *"derivation=git-describe"* ]]
  [[ "$output" == *"is_prerelease=true"* ]]
}

# --- no tags yet ------------------------------------------------------------

@test "no tags -> semver 0.0.0-<n>-g<sha>, git-describe, prerelease" {
  repo="${BATS_TEST_TMPDIR}/notags"
  _init_repo "$repo"
  _commit "$repo" "c1"
  _commit "$repo" "c2"

  run "$DERIVE" --repo "$repo"
  [ "$status" -eq 0 ]
  # <n> is the commit count reachable from HEAD (2 here).
  [[ "$output" =~ semver=0\.0\.0-2-g[0-9a-f]+ ]]
  [[ "$output" == *"derivation=git-describe"* ]]
  [[ "$output" == *"is_prerelease=true"* ]]
}

# --- dirty working tree: fail the build (R1) --------------------------------

@test "dirty working tree fails the build (never publishes -dirty)" {
  repo="${BATS_TEST_TMPDIR}/dirty"
  _init_repo "$repo"
  echo "original" > "$repo/tracked.txt"
  git -C "$repo" add tracked.txt
  git -C "$repo" commit -q -m "c1"
  git -C "$repo" tag v1.2.3
  # Modify a TRACKED file so `git describe --dirty` sees local modifications
  # (an untracked file alone does not make describe report -dirty).
  echo "changed" > "$repo/tracked.txt"

  run "$DERIVE" --repo "$repo"
  [ "$status" -ne 0 ]
  [[ "$output" == *"dirty"* ]]
}

# --- -rc prerelease tag: exact-tag build, still is_prerelease (data model) --

@test "exact prerelease tag v1.0.0-rc1 -> exact-tag but is_prerelease=true" {
  repo="${BATS_TEST_TMPDIR}/rc"
  _init_repo "$repo"
  _commit "$repo" "c1"
  git -C "$repo" tag v1.0.0-rc1

  run "$DERIVE" --repo "$repo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"semver=1.0.0-rc1"* ]]
  [[ "$output" == *"derivation=exact-tag"* ]]
  [[ "$output" == *"is_prerelease=true"* ]]
}

# --- R4: --version override must be an EXISTING tag -------------------------

@test "version override matching an existing tag derives that exact version" {
  repo="${BATS_TEST_TMPDIR}/override-ok"
  _init_repo "$repo"
  _commit "$repo" "c1"
  git -C "$repo" tag v2.0.0
  _commit "$repo" "c2"   # HEAD is past the tag, but the override pins it

  run "$DERIVE" --repo "$repo" --version v2.0.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"semver=2.0.0"* ]]
  [[ "$output" == *"derivation=exact-tag"* ]]
}

@test "version override for a tag that does not exist is rejected (R4)" {
  repo="${BATS_TEST_TMPDIR}/override-bad"
  _init_repo "$repo"
  _commit "$repo" "c1"
  git -C "$repo" tag v1.0.0

  run "$DERIVE" --repo "$repo" --version v9.9.9
  [ "$status" -ne 0 ]
  [[ "$output" == *"v9.9.9"* ]]
}

# --- GITHUB_OUTPUT protocol -------------------------------------------------

@test "writes semver/commit_sha/derivation/is_prerelease/pre_1_0 to GITHUB_OUTPUT" {
  repo="${BATS_TEST_TMPDIR}/ghout"
  _init_repo "$repo"
  _commit "$repo" "c1"
  git -C "$repo" tag v1.4.0

  outfile="${BATS_TEST_TMPDIR}/gh_output"
  : > "$outfile"
  GITHUB_OUTPUT="$outfile" run "$DERIVE" --repo "$repo"
  [ "$status" -eq 0 ]
  grep -q "^semver=1.4.0$" "$outfile"
  grep -q "^derivation=exact-tag$" "$outfile"
  grep -q "^is_prerelease=false$" "$outfile"
  grep -q "^pre_1_0=false$" "$outfile"
  grep -Eq "^commit_sha=[0-9a-f]{40}$" "$outfile"
}

# --- not a git repository ---------------------------------------------------

@test "a non-git directory is a config error, not a silent 0.0.0" {
  repo="${BATS_TEST_TMPDIR}/nogit"
  mkdir -p "$repo"

  run "$DERIVE" --repo "$repo"
  [ "$status" -ne 0 ]
  [[ "$output" == *"git"* ]]
}
