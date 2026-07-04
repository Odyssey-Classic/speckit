#!/usr/bin/env bats
#
# T013: bats unit test for the `run-gate` composite action's core logic
# (.github/actions/run-gate/run-gate.sh, T017). Asserts run-gate normalizes
# an adapter hook's exit code + output into a single, definitive pass/fail
# verdict per gate category (FR-005, SC-003):
#
#   - a passing hook  -> run-gate exits 0 with a `pass` verdict for that
#     category
#   - a failing hook  -> run-gate exits non-zero with a `fail` verdict AND a
#     message naming the category, what failed (on what), and what passing
#     requires (FR-005 verbatim: "which gate failed, on what, and what
#     passing requires")
#   - an unknown category, or a hook missing/empty in the adapter -> a
#     clear, non-zero error (never a silent pass, never a raw yq stack
#     trace)
#   - the security category's severity threshold is read from
#     gate-policy.yml AT RUNTIME, never trusted from the adapter (carried
#     review note) — proven by pointing run-gate at two policy fixtures
#     that differ only in that value and observing the hook's behavior
#     track the policy, not a hardcoded default.
#
# Fixtures: tests/fixtures/run-gate/{adapter.yml, adapter-missing-docs.yml,
# policy.yml, policy-critical.yml} — a stub adapter/policy pair, not a real
# ecosystem, so this test never depends on go/npm/gitleaks/etc. being
# installed (see each fixture's header comment for its controllable hooks).

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  RUN_GATE="${REPO_ROOT}/.github/actions/run-gate/run-gate.sh"
  FIXTURES="${REPO_ROOT}/tests/fixtures/run-gate"
  ADAPTER="${FIXTURES}/adapter.yml"
  ADAPTER_MISSING_DOCS="${FIXTURES}/adapter-missing-docs.yml"
  POLICY="${FIXTURES}/policy.yml"
  POLICY_CRITICAL="${FIXTURES}/policy-critical.yml"
}

# --- passing hook -----------------------------------------------------------

@test "run-gate.sh exits 0 with a pass verdict when the hook passes (tests category)" {
  run "$RUN_GATE" --adapter "$ADAPTER" --category tests --policy "$POLICY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"category=tests"* ]]
  [[ "$output" == *"verdict=pass"* ]]
}

@test "run-gate.sh exits 0 with a pass verdict for docs category" {
  run "$RUN_GATE" --adapter "$ADAPTER" --category docs --policy "$POLICY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"category=docs"* ]]
  [[ "$output" == *"verdict=pass"* ]]
}

# --- failing hook ------------------------------------------------------------

@test "run-gate.sh exits non-zero with a fail verdict when the hook fails (quality category)" {
  run "$RUN_GATE" --adapter "$ADAPTER" --category quality --policy "$POLICY"
  [ "$status" -ne 0 ]
  [[ "$output" == *"category=quality"* ]]
  [[ "$output" == *"verdict=fail"* ]]
}

@test "a failing hook's message names the category, what failed, and what passing requires (FR-005)" {
  run "$RUN_GATE" --adapter "$ADAPTER" --category quality --policy "$POLICY"
  [ "$status" -ne 0 ]
  # which category failed
  [[ "$output" == *"quality"* ]]
  # on what: the underlying evidence/output from the hook itself
  [[ "$output" == *"formatting violation in fixtures/foo.stub"* ]]
  # what passing requires
  [[ "$output" == *"to pass"* ]]
  [[ "$output" == *"requires"* ]]
}

# --- GITHUB_OUTPUT `message` output (T016 review fix) ------------------------
#
# gate.yml (T016) previously re-invoked this exact script a second time on
# the failure path, only to capture its RUN_GATE_MESSAGE: text for the step
# summary — a double-run of the hook that risked describing a DIFFERENT
# failure than the one that actually blocked, for any non-deterministic
# hook. Instead, run-gate.sh now exposes that same text as a `message`
# GITHUB_OUTPUT (heredoc-delimited, multi-line), alongside the pre-existing
# `verdict`/`category` outputs, so a caller reads it without a second
# invocation. Stdout behavior (asserted above) is unchanged.

@test "a failing hook writes verdict, category, and a multi-line message output to GITHUB_OUTPUT" {
  output_file="${BATS_TEST_TMPDIR}/github_output_fail"
  : > "${output_file}"
  GITHUB_OUTPUT="${output_file}" run "$RUN_GATE" --adapter "$ADAPTER" --category quality --policy "$POLICY"
  [ "$status" -ne 0 ]
  run cat "${output_file}"
  [[ "$output" == *"category=quality"* ]]
  [[ "$output" == *"verdict=fail"* ]]
  [[ "$output" == *"message<<"* ]]
  [[ "$output" == *"RUN_GATE_MESSAGE:"* ]]
  [[ "$output" == *"formatting violation in fixtures/foo.stub"* ]]
  [[ "$output" == *"to pass"* ]]
}

@test "a passing hook writes verdict/category to GITHUB_OUTPUT but no message output" {
  output_file="${BATS_TEST_TMPDIR}/github_output_pass"
  : > "${output_file}"
  GITHUB_OUTPUT="${output_file}" run "$RUN_GATE" --adapter "$ADAPTER" --category tests --policy "$POLICY"
  [ "$status" -eq 0 ]
  run cat "${output_file}"
  [[ "$output" == *"category=tests"* ]]
  [[ "$output" == *"verdict=pass"* ]]
  [[ "$output" != *"message<<"* ]]
}

# --- unknown category / missing hook -----------------------------------------

@test "an unknown category is a clear non-zero error" {
  run "$RUN_GATE" --adapter "$ADAPTER" --category bogus --policy "$POLICY"
  [ "$status" -ne 0 ]
  [[ "$output" == *"bogus"* ]]
  [[ "$output" == *"unknown category"* || "$output" == *"not declared"* ]]
}

@test "a category not declared in the policy is a clear non-zero error" {
  # 'quality' is a valid category name, but this minimal policy fixture only
  # declares 'tests' — proves run-gate actually consults the policy file
  # rather than only validating against its own fixed enum.
  cat > "${BATS_TEST_TMPDIR}/policy-partial.yml" <<'EOF'
policy_version: "0.0.0-test"
categories:
  - name: tests
    required: true
    threshold: { must_pass: all }
EOF
  run "$RUN_GATE" --adapter "$ADAPTER" --category quality --policy "${BATS_TEST_TMPDIR}/policy-partial.yml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"quality"* ]]
}

@test "a hook missing entirely from the adapter is a clear non-zero error" {
  run "$RUN_GATE" --adapter "$ADAPTER_MISSING_DOCS" --category docs --policy "$POLICY"
  [ "$status" -ne 0 ]
  [[ "$output" == *"docs"* ]]
}

@test "a hook present but with an empty run: command is a clear non-zero error" {
  cat > "${BATS_TEST_TMPDIR}/adapter-empty-run.yml" <<'EOF'
adapter:
  id: stub-empty
  ecosystem: stub
hooks:
  test:
    description: "empty run"
    run: ""
  lint:
    description: "empty run"
    run: ""
  security:
    description: "empty run"
    run: ""
  docs:
    description: "empty run"
    run: ""
EOF
  run "$RUN_GATE" --adapter "${BATS_TEST_TMPDIR}/adapter-empty-run.yml" --category tests --policy "$POLICY"
  [ "$status" -ne 0 ]
}

@test "missing required arguments is a clear non-zero usage error" {
  run "$RUN_GATE" --category tests --policy "$POLICY"
  [ "$status" -ne 0 ]
}

@test "a non-existent adapter file is a clear non-zero error" {
  run "$RUN_GATE" --adapter "${FIXTURES}/does-not-exist.yml" --category tests --policy "$POLICY"
  [ "$status" -ne 0 ]
}

@test "a non-existent policy file is a clear non-zero error" {
  run "$RUN_GATE" --adapter "$ADAPTER" --category tests --policy "${FIXTURES}/does-not-exist.yml"
  [ "$status" -ne 0 ]
}

# --- dangling value-taking flags (last token, no value) ----------------------
#
# Each of --adapter/--category/--policy consumes its value via `shift 2`.
# Given as the very last command-line token, there is no second positional
# parameter to shift past — must hit the script's own usage-error path
# (EXIT_USAGE=2 + a message), never abort silently.

@test "--adapter as the last token with no value is a usage error, not a silent exit (dangling-flag footgun)" {
  run "$RUN_GATE" --category tests --policy "$POLICY" --adapter
  [ "$status" -eq 2 ]
  [ -n "$output" ]
}

@test "--category as the last token with no value is a usage error, not a silent exit (dangling-flag footgun)" {
  run "$RUN_GATE" --adapter "$ADAPTER" --policy "$POLICY" --category
  [ "$status" -eq 2 ]
  [ -n "$output" ]
}

@test "--policy as the last token with no value is a usage error, not a silent exit (dangling-flag footgun)" {
  run "$RUN_GATE" --adapter "$ADAPTER" --category tests --policy
  [ "$status" -eq 2 ]
  [ -n "$output" ]
}

# --- security threshold sourced from policy at runtime (carried review note) -

@test "security hook receives min_severity_block=high sourced from the policy fixture" {
  EXPECTED_MIN_SEVERITY_BLOCK=high run "$RUN_GATE" --adapter "$ADAPTER" --category security --policy "$POLICY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
  [[ "$output" == *"threshold=high"* ]]
}

@test "security hook receives min_severity_block=critical when the policy fixture says critical (not hardcoded)" {
  EXPECTED_MIN_SEVERITY_BLOCK=critical run "$RUN_GATE" --adapter "$ADAPTER" --category security --policy "$POLICY_CRITICAL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
  [[ "$output" == *"threshold=critical"* ]]
}

@test "security hook fails verdict if the adapter's own expectation diverges from the sourced policy threshold" {
  # Sanity check on the sanity check: if the test harness itself expected the
  # WRONG value, the stub hook (and therefore run-gate) must fail — proving
  # the prior two green tests are not vacuously true.
  EXPECTED_MIN_SEVERITY_BLOCK=critical run "$RUN_GATE" --adapter "$ADAPTER" --category security --policy "$POLICY"
  [ "$status" -ne 0 ]
  [[ "$output" == *"verdict=fail"* ]]
}

# --- D12 baseline diff wiring (T018) -----------------------------------------
#
# security-baseline.sh (T014/T018) is unit-tested on its own in
# tests/unit/test_security_baseline.bats. These three tests instead prove
# the SEAM in run-gate.sh actually calls it and honors its verdict when a
# CI-integration step has provided the two findings files, and that
# run-gate honestly falls back to the raw hook exit code — with a clear
# log saying so — when it has not (fixtures shared with
# test_security_baseline.bats: tests/fixtures/security-baseline/).

@test "security category blocks via D12 baseline diff on a newly-introduced high finding, even though the underlying hook itself passes" {
  SECURITY_BASELINE_FIXTURES="${REPO_ROOT}/tests/fixtures/security-baseline"
  RUN_GATE_SECURITY_CURRENT_FINDINGS_FILE="${SECURITY_BASELINE_FIXTURES}/current-new-high.findings" \
    RUN_GATE_SECURITY_BASELINE_FINDINGS_FILE="${SECURITY_BASELINE_FIXTURES}/baseline-unrelated.findings" \
    run "$RUN_GATE" --adapter "$ADAPTER" --category security --policy "$POLICY"
  [ "$status" -ne 0 ]
  [[ "$output" == *"D12 baseline diff ACTIVE"* ]]
  [[ "$output" == *"stub security hook: ok"* ]] # the underlying hook itself passed...
  [[ "$output" == *"SECURITY_BASELINE_RESULT verdict=block"* ]]
  [[ "$output" == *"verdict=fail"* ]] # ...but run-gate's final verdict blocks (D12 override)
}

@test "security category passes via D12 baseline diff when the only newly-introduced finding is below threshold" {
  SECURITY_BASELINE_FIXTURES="${REPO_ROOT}/tests/fixtures/security-baseline"
  RUN_GATE_SECURITY_CURRENT_FINDINGS_FILE="${SECURITY_BASELINE_FIXTURES}/current-new-low.findings" \
    RUN_GATE_SECURITY_BASELINE_FINDINGS_FILE="${SECURITY_BASELINE_FIXTURES}/baseline-unrelated.findings" \
    run "$RUN_GATE" --adapter "$ADAPTER" --category security --policy "$POLICY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"D12 baseline diff ACTIVE"* ]]
  [[ "$output" == *"SECURITY_BASELINE_RESULT verdict=pass"* ]]
  [[ "$output" == *"verdict=pass"* ]]
}

@test "security category falls back to the raw hook exit code, with a clear log, when D12 findings files are not provided" {
  run "$RUN_GATE" --adapter "$ADAPTER" --category security --policy "$POLICY"
  [ "$status" -eq 0 ]
  [[ "$output" == *"D12 baseline diff NOT active"* ]]
  [[ "$output" == *"verdict=pass"* ]]
}
