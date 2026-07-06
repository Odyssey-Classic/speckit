#!/usr/bin/env bats
#
# T006: validates policy/gate-policy.yml against the contract in
# specs/001-cicd-pipeline/contracts/gate-policy.schema.md (FR-002, FR-004,
# FR-006). Asserts:
#   - all four required gate categories (tests/quality/security/docs) are
#     present and marked `required: true`
#   - `security.threshold.min_severity_block` is `high`
#   - at least one exemption is declared and every one carries a description
#   - `bypass.requires` is set (never `none`) and `bypass.must_record`
#     includes both `actor` and `reason`
#
# Parsing: `yq` (mikefarah v4). It is preinstalled on GitHub-hosted ubuntu
# runners (no `pip`/extra install step), and it is the same parser Phase 3's
# run-gate/gate.yml uses to read this file at runtime — so the test validates
# the policy through the exact tool the gate enforces it with, avoiding a
# two-parser divergence on a consumer-pinned governance artifact. `yq -e`
# exits non-zero when its expression evaluates to false/null, so each
# assertion below is a single boolean yq query.

setup() {
  POLICY_FILE="${BATS_TEST_DIRNAME}/../../policy/gate-policy.yml"
}

# Assert a yq boolean expression holds against the policy file.
_policy() {
  run yq -e "$1" "$POLICY_FILE"
  if [ "$status" -ne 0 ]; then
    echo "FAIL: yq expression did not hold (status $status): $1" >&2
    echo "yq output: $output" >&2
  fi
  [ "$status" -eq 0 ]
}

@test "policy/gate-policy.yml exists and parses as YAML" {
  [ -f "$POLICY_FILE" ]
  _policy '. != null'
}

@test "all four required gate categories (tests, quality, security, docs) are present" {
  _policy '[.categories[].name] | contains(["tests", "quality", "security", "docs"])'
}

@test "tests, quality, security, and docs categories are each marked required: true" {
  _policy '[.categories[] | select((.name == "tests" or .name == "quality" or .name == "security" or .name == "docs") and .required == true)] | length == 4'
}

@test "security.threshold.min_severity_block is set to high" {
  _policy '.categories[] | select(.name == "security") | .threshold.min_severity_block == "high"'
}

@test "at least one exemption is declared and every exemption has a description" {
  _policy '(.exemptions | length > 0) and ([.exemptions[] | select((.description // "") == "")] | length == 0)'
}

@test "bypass.requires is set and is not none" {
  _policy '.bypass.requires != null and .bypass.requires != "none" and .bypass.requires != ""'
}

@test "bypass.must_record includes both actor and reason" {
  _policy '.bypass.must_record | contains(["actor", "reason"])'
}
