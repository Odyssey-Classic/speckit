#!/usr/bin/env bats
#
# T014: bats unit test for the security-baseline diff classifier
# (.github/actions/run-gate/security-baseline.sh, T018). This is the pure,
# standalone classification core behind the security gate's D12 rule
# (FR-004, research.md D12): newly-introduced findings at/above the policy
# severity threshold BLOCK; pre-existing findings are SURFACED (reported,
# never block on their own) — "don't punish a contributor for a
# vulnerability they didn't introduce, while still preventing new risk."
#
# Classification is by FINGERPRINT ONLY: a current finding is "new" if its
# fingerprint does not appear anywhere in the baseline file, "preexisting"
# if it does — see security-baseline.sh's header comment for the full
# finding-format contract (`<severity>\t<fingerprint>` per line).
#
# Fixtures: tests/fixtures/security-baseline/*.findings — hand-authored
# stub finding files (not real scanner output) so this test never depends
# on any actual security scanner being installed.

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  SCRIPT="${REPO_ROOT}/.github/actions/run-gate/security-baseline.sh"
  FIXTURES="${REPO_ROOT}/tests/fixtures/security-baseline"
}

# --- BLOCK: newly-introduced at/above threshold ------------------------------

@test "a newly-introduced 'high' finding blocks when threshold is high" {
  run "$SCRIPT" --current "${FIXTURES}/current-new-high.findings" \
                --baseline "${FIXTURES}/baseline-unrelated.findings" \
                --min-severity high
  [ "$status" -ne 0 ]
  [[ "$output" == *"classification=new"* ]]
  [[ "$output" == *"severity=high"* ]]
  [[ "$output" == *"fingerprint=FP-NEW-HIGH-1"* ]]
  [[ "$output" == *"action=block"* ]]
  [[ "$output" == *"SECURITY_BASELINE_RESULT verdict=block"* ]]
}

@test "a newly-introduced 'critical' finding blocks when threshold is high" {
  run "$SCRIPT" --current "${FIXTURES}/current-new-critical.findings" \
                --baseline "${FIXTURES}/baseline-unrelated.findings" \
                --min-severity high
  [ "$status" -ne 0 ]
  [[ "$output" == *"classification=new"* ]]
  [[ "$output" == *"severity=critical"* ]]
  [[ "$output" == *"action=block"* ]]
  [[ "$output" == *"SECURITY_BASELINE_RESULT verdict=block"* ]]
}

@test "a newly-introduced finding exactly at the threshold blocks (>=, not >)" {
  run "$SCRIPT" --current "${FIXTURES}/current-new-medium.findings" \
                --baseline "${FIXTURES}/baseline-unrelated.findings" \
                --min-severity medium
  [ "$status" -ne 0 ]
  [[ "$output" == *"severity=medium"* ]]
  [[ "$output" == *"action=block"* ]]
  [[ "$output" == *"SECURITY_BASELINE_RESULT verdict=block"* ]]
}

# --- SURFACE, never block on their own: pre-existing + below-threshold ------

@test "a pre-existing 'high' finding (present in both) is surfaced, not blocked" {
  run "$SCRIPT" --current "${FIXTURES}/current-existing-high.findings" \
                --baseline "${FIXTURES}/baseline-existing-high.findings" \
                --min-severity high
  [ "$status" -eq 0 ]
  [[ "$output" == *"classification=preexisting"* ]]
  [[ "$output" == *"severity=high"* ]]
  [[ "$output" == *"action=surface"* ]]
  [[ "$output" == *"SECURITY_BASELINE_RESULT verdict=pass"* ]]
}

@test "a newly-introduced 'low' finding, below the high threshold, is surfaced not blocked" {
  run "$SCRIPT" --current "${FIXTURES}/current-new-low.findings" \
                --baseline "${FIXTURES}/baseline-unrelated.findings" \
                --min-severity high
  [ "$status" -eq 0 ]
  [[ "$output" == *"classification=new"* ]]
  [[ "$output" == *"severity=low"* ]]
  [[ "$output" == *"action=surface"* ]]
  [[ "$output" == *"SECURITY_BASELINE_RESULT verdict=pass"* ]]
}

# --- empty findings -----------------------------------------------------------

@test "empty current and baseline findings pass with zero totals" {
  run "$SCRIPT" --current "${FIXTURES}/empty.findings" \
                --baseline "${FIXTURES}/empty.findings" \
                --min-severity high
  [ "$status" -eq 0 ]
  [[ "$output" == *"SECURITY_BASELINE_RESULT verdict=pass"* ]]
  [[ "$output" == *"total=0"* ]]
}

# --- mixed: pre-existing does not save a co-occurring newly-introduced block -

@test "mixed pre-existing critical + newly-introduced high blocks because of the new high, not the pre-existing critical" {
  run "$SCRIPT" --current "${FIXTURES}/current-mixed.findings" \
                --baseline "${FIXTURES}/baseline-mixed.findings" \
                --min-severity high
  [ "$status" -ne 0 ]
  # the pre-existing critical is surfaced, not the reason for blocking
  [[ "$output" == *"classification=preexisting"* ]]
  [[ "$output" == *"severity=critical"* ]]
  [[ "$output" == *"fingerprint=FP-EXISTING-CRITICAL-1"* ]]
  # the newly-introduced high is what blocks
  [[ "$output" == *"classification=new"* ]]
  [[ "$output" == *"fingerprint=FP-NEW-HIGH-2"* ]]
  [[ "$output" == *"action=block"* ]]
  [[ "$output" == *"SECURITY_BASELINE_RESULT verdict=block"* ]]
  [[ "$output" == *"total=2"* ]]
  [[ "$output" == *"new=1"* ]]
  [[ "$output" == *"preexisting=1"* ]]
  [[ "$output" == *"blocking=1"* ]]
}

# --- error paths ---------------------------------------------------------------

@test "an unknown severity word is a clear non-zero error, not a silent pass" {
  run "$SCRIPT" --current "${FIXTURES}/current-malformed-severity.findings" \
                --baseline "${FIXTURES}/empty.findings" \
                --min-severity high
  [ "$status" -ne 0 ]
  [[ "$output" == *"bogus"* ]]
}

@test "missing required arguments is a clear non-zero usage error" {
  run "$SCRIPT" --current "${FIXTURES}/empty.findings" --min-severity high
  [ "$status" -ne 0 ]
}

@test "a non-existent current findings file is a clear non-zero error" {
  run "$SCRIPT" --current "${FIXTURES}/does-not-exist.findings" \
                --baseline "${FIXTURES}/empty.findings" \
                --min-severity high
  [ "$status" -ne 0 ]
}

@test "an unknown --min-severity value is a clear non-zero error" {
  run "$SCRIPT" --current "${FIXTURES}/empty.findings" \
                --baseline "${FIXTURES}/empty.findings" \
                --min-severity extreme
  [ "$status" -ne 0 ]
}
