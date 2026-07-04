#!/usr/bin/env bats
#
# T020: bats unit test for the central docs-gate "user-facing change ships
# with docs" check (scripts/check-docs-required.sh). FR-002 / Constitution
# Principle VI ("Docs as a Feature"): a feature without its creator- and/or
# player-facing documentation is unfinished and must not be considered
# complete.
#
# THE RULE (documented in full in the script's header comment):
#   - A changed file is NON-user-facing (exempt from needing docs on its
#     own) iff it falls under one of: docs/**, tests/**, .github/**,
#     specs/**. Everything else is user-facing.
#   - A changed file is a DOCS file iff it falls under docs/** or matches
#     **/*.md (any Markdown file, anywhere).
#   - FAIL iff: at least one changed file is user-facing, AND no changed
#     file is a docs file, AND no exemption signal was given.
#   - Otherwise PASS (including: no changes at all; docs-only changes;
#     only non-user-facing-prefix changes; or an exemption was given).
#
# Fixtures: tests/fixtures/docs-required/*.files — stub changed-files lists
# (one path per line; blank lines and '#' comments ignored), not real git
# diff output, so this test never depends on being run inside a real git
# checkout or PR.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  SCRIPT="${REPO_ROOT}/scripts/check-docs-required.sh"
  FIXTURES="${REPO_ROOT}/tests/fixtures/docs-required"
}

# --- user-facing change ------------------------------------------------------

@test "user-facing change + a docs change passes" {
  run "$SCRIPT" --changed-files "${FIXTURES}/user-facing-with-docs.files"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
}

@test "user-facing change + no docs change fails" {
  run "$SCRIPT" --changed-files "${FIXTURES}/user-facing-no-docs.files"
  [ "$status" -ne 0 ]
  [[ "$output" == *"verdict=fail"* ]]
}

# --- docs-only / non-user-facing-only changes pass trivially -----------------

@test "docs-only change passes" {
  run "$SCRIPT" --changed-files "${FIXTURES}/docs-only.files"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
}

@test "changes confined to non-user-facing prefixes (tests/**, .github/**, specs/**) pass even without a docs file" {
  run "$SCRIPT" --changed-files "${FIXTURES}/non-user-facing-no-docs.files"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
}

# --- exemption ----------------------------------------------------------------

@test "an exempt user-facing change with no docs passes" {
  run "$SCRIPT" --changed-files "${FIXTURES}/user-facing-no-docs.files" --exempt
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
  [[ "$output" == *"exempt"* ]]
}

# --- no changes -----------------------------------------------------------------

@test "no changes at all passes" {
  run "$SCRIPT" --changed-files "${FIXTURES}/empty.files"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
}

# --- stdin form -------------------------------------------------------------

@test "'--changed-files -' reads the changed-files list from stdin" {
  run bash -c "cat '${FIXTURES}/user-facing-no-docs.files' | '${SCRIPT}' --changed-files -"
  [ "$status" -ne 0 ]
  [[ "$output" == *"verdict=fail"* ]]
}

# --- FR-005: failure message names the category, what failed, what passing requires

@test "a failing docs-required check's message names the category, what failed, and what passing requires (FR-005)" {
  run "$SCRIPT" --changed-files "${FIXTURES}/user-facing-no-docs.files"
  [ "$status" -ne 0 ]
  # which category failed
  [[ "$output" == *"docs"* ]]
  # on what: the offending user-facing file
  [[ "$output" == *"server/internal/widget/widget.go"* ]]
  # what passing requires
  [[ "$output" == *"docs/"* ]]
  [[ "$output" == *"*.md"* || "$output" == *".md"* ]]
}

# --- usage errors --------------------------------------------------------------

@test "missing --changed-files is a clear non-zero usage error" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "a non-existent changed-files file is a clear non-zero usage error" {
  run "$SCRIPT" --changed-files "${FIXTURES}/does-not-exist.files"
  [ "$status" -ne 0 ]
}
