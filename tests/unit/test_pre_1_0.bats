#!/usr/bin/env bats
#
# T026 (US2): bats unit test for the pre-1.0 compatibility disclaimer in the
# `derive-version` script (.github/actions/derive-version/derive-version.sh,
# T028/T030). Per FR-011 and contracts/version-derivation.md R3:
#
#   MAJOR == 0  =>  pre_1_0 = true  =>  a compatibility disclaimer is attached
#   to the version output (and, downstream in US3, to release notes).
#
# The disclaimer is emitted as a `DERIVE_VERSION_DISCLAIMER:` line on stdout
# and a `disclaimer=` key in GITHUB_OUTPUT so a release workflow (T035) can
# graft it into notes without re-deriving. A >= 1.0.0 version carries neither.
#
# Fixtures are throwaway git repos under $BATS_TEST_TMPDIR (git-only, no
# network), same helper shape as test_version_derivation.bats.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  DERIVE="${REPO_ROOT}/.github/actions/derive-version/derive-version.sh"
}

_init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email "tester@example.com"
  git -C "$dir" config user.name "Tester"
  git -C "$dir" config commit.gpgsign false
  # Global tag.gpgsign=true would make `git tag <name>` a signed annotated
  # tag needing a message; force lightweight tags so fixtures stay hermetic.
  git -C "$dir" config tag.gpgsign false
}

_commit() {
  git -C "$1" commit -q --allow-empty -m "$2"
}

# --- MAJOR == 0 attaches the disclaimer -------------------------------------

@test "0.x release tag sets pre_1_0=true and attaches the compatibility disclaimer" {
  repo="${BATS_TEST_TMPDIR}/zero"
  _init_repo "$repo"
  _commit "$repo" "c1"
  git -C "$repo" tag v0.3.0

  run "$DERIVE" --repo "$repo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"semver=0.3.0"* ]]
  [[ "$output" == *"pre_1_0=true"* ]]
  [[ "$output" == *"DERIVE_VERSION_DISCLAIMER:"* ]]
  [[ "$output" == *"compatibility"* ]]
  # A clean 0.x tag is a real (pre-1.0) release, not a prerelease build — it
  # must remain releasable (US3 R1), so is_prerelease stays false here; the
  # 0.x signal is carried by pre_1_0, not is_prerelease.
  [[ "$output" == *"is_prerelease=false"* ]]
}

@test "no-tags 0.0.0 build is pre_1_0=true and carries the disclaimer" {
  repo="${BATS_TEST_TMPDIR}/zero-untagged"
  _init_repo "$repo"
  _commit "$repo" "c1"

  run "$DERIVE" --repo "$repo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pre_1_0=true"* ]]
  [[ "$output" == *"DERIVE_VERSION_DISCLAIMER:"* ]]
}

# --- MAJOR >= 1 carries neither ---------------------------------------------

@test "1.x release tag sets pre_1_0=false and emits NO disclaimer" {
  repo="${BATS_TEST_TMPDIR}/one"
  _init_repo "$repo"
  _commit "$repo" "c1"
  git -C "$repo" tag v1.0.0

  run "$DERIVE" --repo "$repo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pre_1_0=false"* ]]
  [[ "$output" != *"DERIVE_VERSION_DISCLAIMER:"* ]]
}

# --- GITHUB_OUTPUT carries the disclaimer for downstream release notes ------

@test "disclaimer is exposed in GITHUB_OUTPUT for a 0.x build" {
  repo="${BATS_TEST_TMPDIR}/zero-ghout"
  _init_repo "$repo"
  _commit "$repo" "c1"
  git -C "$repo" tag v0.9.1

  outfile="${BATS_TEST_TMPDIR}/gh_output"
  : > "$outfile"
  GITHUB_OUTPUT="$outfile" run "$DERIVE" --repo "$repo"
  [ "$status" -eq 0 ]
  grep -q "^pre_1_0=true$" "$outfile"
  # disclaimer is a single-line key here; assert it is present and non-empty.
  grep -Eq "^disclaimer=.+" "$outfile"
}
