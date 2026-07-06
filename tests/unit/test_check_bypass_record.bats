#!/usr/bin/env bats
#
# T022 (FR-006, SC-001): bats unit test for scripts/check-bypass-record.sh —
# the record-completeness gate behind "any bypass of a required gate MUST
# be recorded, attributed to a named person, and justified in writing;
# silent bypass MUST NOT be possible."
#
# What this gate must do:
#   - if policy.bypass.allowed is false, EVERY bypass is rejected — even
#     one carrying an otherwise-complete record (a complete record is not
#     permission to bypass when policy disallows bypass outright).
#   - otherwise, EVERY field named in policy.bypass.must_record MUST be
#     present AND non-empty in the record; a missing or empty required
#     field is rejected with a clear message naming the field.
#   - a complete record passes AND is echoed to the log (the
#     "attributable + logged" half of FR-006), so the fact of the bypass
#     and who/why it happened is never silent.
#   - the set of required fields comes from policy.bypass.must_record at
#     runtime, not from a value hardcoded in the script: a policy fixture
#     whose must_record adds a third field ("ticket") beyond actor/reason
#     must make that field required too (tests/fixtures/bypass-record/
#     policy-extra-field.yml).
#
# Fixtures: tests/fixtures/bypass-record/ (policy variants + canonical
# complete records, following the same "policy variant proves sourced-not-
# hardcoded" convention as tests/fixtures/run-gate/policy-critical.yml).
# Case-specific negative records (missing/empty field) are written inline
# to $BATS_TEST_TMPDIR, same convention as
# tests/unit/test_check_adapter_overrides.bats's inline adapter fixtures.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  SCRIPT="${REPO_ROOT}/scripts/check-bypass-record.sh"
  FIXTURES="${REPO_ROOT}/tests/fixtures/bypass-record"
  DEFAULT_POLICY="${FIXTURES}/policy.yml"
}

# --- complete record: pass, and echoed to the log ----------------------------

@test "a complete record (actor + reason both non-empty) passes under the default policy" {
  run "$SCRIPT" --record "${FIXTURES}/record-complete.txt" --policy "$DEFAULT_POLICY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
}

@test "a passing record is echoed to the log (attributable + logged)" {
  run "$SCRIPT" --record "${FIXTURES}/record-complete.txt" --policy "$DEFAULT_POLICY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"actor='alice'"* ]]
  [[ "$output" == *"reason='prod registry outage"* ]]
}

@test "--record - reads a complete record from stdin and passes" {
  run bash -c "cat '${FIXTURES}/record-complete.txt' | '${SCRIPT}' --record - --policy '${DEFAULT_POLICY}'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
}

# --- missing / empty required field: fail, naming the field -----------------

@test "a record missing the reason field fails, naming 'reason'" {
  cat > "${BATS_TEST_TMPDIR}/record-missing-reason.txt" <<'EOF'
actor: alice
EOF
  run "$SCRIPT" --record "${BATS_TEST_TMPDIR}/record-missing-reason.txt" --policy "$DEFAULT_POLICY"
  [ "$status" -ne 0 ]
  [[ "$output" == *"reason"* ]]
}

@test "a record with an empty actor value fails, naming 'actor'" {
  cat > "${BATS_TEST_TMPDIR}/record-empty-actor.txt" <<'EOF'
actor:
reason: on-call approved a temporary bypass during an active incident
EOF
  run "$SCRIPT" --record "${BATS_TEST_TMPDIR}/record-empty-actor.txt" --policy "$DEFAULT_POLICY"
  [ "$status" -ne 0 ]
  [[ "$output" == *"actor"* ]]
}

@test "a record with a blank (whitespace-only) reason value fails, naming 'reason'" {
  cat > "${BATS_TEST_TMPDIR}/record-blank-reason.txt" <<'EOF'
actor: alice
reason:
EOF
  run "$SCRIPT" --record "${BATS_TEST_TMPDIR}/record-blank-reason.txt" --policy "$DEFAULT_POLICY"
  [ "$status" -ne 0 ]
  [[ "$output" == *"reason"* ]]
}

@test "an entirely empty record fails, naming both required fields" {
  : > "${BATS_TEST_TMPDIR}/record-empty.txt"
  run "$SCRIPT" --record "${BATS_TEST_TMPDIR}/record-empty.txt" --policy "$DEFAULT_POLICY"
  [ "$status" -ne 0 ]
  [[ "$output" == *"actor"* ]]
  [[ "$output" == *"reason"* ]]
}

# --- bypass.allowed: false rejects ANY bypass --------------------------------

@test "policy with bypass.allowed: false rejects even a complete record" {
  run "$SCRIPT" --record "${FIXTURES}/record-complete.txt" --policy "${FIXTURES}/policy-not-allowed.yml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"allowed"* ]]
}

# --- must_record is sourced from policy, not hardcoded -----------------------

@test "a policy whose must_record adds a third field ('ticket') requires it too" {
  run "$SCRIPT" --record "${FIXTURES}/record-complete.txt" --policy "${FIXTURES}/policy-extra-field.yml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ticket"* ]]
}

@test "a record satisfying the extended must_record (actor+reason+ticket) passes" {
  run "$SCRIPT" --record "${FIXTURES}/record-complete-with-ticket.txt" --policy "${FIXTURES}/policy-extra-field.yml"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
  [[ "$output" == *"ticket='OPS-4821'"* ]]
}

# --- usage errors -------------------------------------------------------------

@test "missing --record is a clear non-zero usage error" {
  run "$SCRIPT" --policy "$DEFAULT_POLICY"
  [ "$status" -eq 2 ]
}

@test "a non-existent record file is a clear non-zero usage error" {
  run "$SCRIPT" --record "${REPO_ROOT}/does/not/exist.txt" --policy "$DEFAULT_POLICY"
  [ "$status" -eq 2 ]
}

@test "a non-existent policy file is a clear non-zero usage error" {
  run "$SCRIPT" --record "${FIXTURES}/record-complete.txt" --policy "${REPO_ROOT}/does/not/exist.yml"
  [ "$status" -eq 2 ]
}
