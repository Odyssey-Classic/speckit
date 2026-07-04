#!/usr/bin/env bats
#
# T019: bats unit test for the central quality-gate license-side check
# (scripts/check-license-side.sh). FR-021 (Constitution Principle III)
# requires every repository to have declared which side of the licensing
# line it occupies — exactly "agpl-core" (engine core, AGPL-3.0) or
# "apache-edge" (ecosystem edge, Apache-2.0) — and to block when it hasn't.
#
# This check is deliberately dumb: it validates the declared VALUE
# gate.yml (T016, not yet authored) passes through from its own
# `license_side` input (contracts/reusable-workflow-interface.md). It never
# inspects repo contents to infer or cross-check the side.
#
# No fixtures needed — the input is a single scalar value passed as a flag,
# positional argument, or the LICENSE_SIDE env var.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  SCRIPT="${REPO_ROOT}/scripts/check-license-side.sh"
}

# --- valid declarations pass --------------------------------------------------

@test "agpl-core (positional) passes" {
  run "$SCRIPT" agpl-core
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
  [[ "$output" == *"agpl-core"* ]]
}

@test "apache-edge (--license-side flag) passes" {
  run "$SCRIPT" --license-side apache-edge
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
  [[ "$output" == *"apache-edge"* ]]
}

@test "LICENSE_SIDE env var is honored when no flag/positional argument is given" {
  LICENSE_SIDE=agpl-core run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
}

@test "a flag/positional argument takes precedence over the LICENSE_SIDE env var" {
  LICENSE_SIDE=apache-edge run "$SCRIPT" agpl-core
  [ "$status" -eq 0 ]
  [[ "$output" == *"agpl-core"* ]]
}

# --- invalid declarations fail loudly (FR-021) --------------------------------

@test "an empty declaration fails" {
  run "$SCRIPT" ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"verdict=fail"* ]]
}

@test "no declaration at all (no flag, no positional, no env var) fails" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"verdict=fail"* ]]
}

@test "an unknown value ('gpl') fails" {
  run "$SCRIPT" gpl
  [ "$status" -ne 0 ]
  [[ "$output" == *"verdict=fail"* ]]
  [[ "$output" == *"gpl"* ]]
}

@test "a wrong-case value ('AGPL-Core') fails — case is significant" {
  run "$SCRIPT" AGPL-Core
  [ "$status" -ne 0 ]
  [[ "$output" == *"verdict=fail"* ]]
}

# --- FR-005: failure message names the category, what failed, what passing requires

@test "a failing declaration's message names the category, what failed, and what passing requires (FR-005)" {
  run "$SCRIPT" gpl
  [ "$status" -ne 0 ]
  # which category failed
  [[ "$output" == *"quality"* ]]
  # on what: the offending declared value
  [[ "$output" == *"'gpl'"* ]]
  # what passing requires
  [[ "$output" == *"agpl-core"* ]]
  [[ "$output" == *"apache-edge"* ]]
}

# --- usage errors --------------------------------------------------------------

@test "an unknown flag is a clear non-zero usage error" {
  run "$SCRIPT" --bogus-flag agpl-core
  [ "$status" -ne 0 ]
}

@test "--license-side as the last token with no value is a usage error, not a silent exit (dangling-flag footgun)" {
  run "$SCRIPT" --license-side
  [ "$status" -eq 2 ]
  [ -n "$output" ]
}
