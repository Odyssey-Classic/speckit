#!/usr/bin/env bats
#
# T006: validates policy/gate-policy.yml against the contract in
# specs/001-cicd-pipeline/contracts/gate-policy.schema.md (FR-002, FR-004,
# FR-006). Asserts:
#   - all four required gate categories (tests/quality/security/docs) are
#     present and marked `required: true`
#   - `security.threshold.min_severity_block` is `high`
#   - every `exemptions[]` entry carries a non-empty `description`
#   - `bypass.requires` is set (never `none`) and `bypass.must_record`
#     includes both `actor` and `reason`
#
# Parsing approach: python3's `yaml` module (PyYAML). Structural checks over
# nested YAML (list-of-maps categories/exemptions, mixed scalar/list
# thresholds) are easy to get subtly wrong with grep/awk; a real parser gives
# exact, unambiguous answers. `python3 -c "import yaml"` was confirmed to
# succeed in this environment before choosing this approach — no new system
# dependency was installed. This is a soft runtime dependency: wherever
# `make test` / this bats suite runs, `python3` with PyYAML must be
# importable. See tasks.md T005/T006 report for the fallback if that ever
# stops being true (a hand-rolled grep/awk check, more fragile but
# dependency-free).

setup() {
  POLICY_FILE="${BATS_TEST_DIRNAME}/../../policy/gate-policy.yml"
}

# Loads $POLICY_FILE as YAML and evaluates the python snippet given as $1,
# which must set `ok = <bool>`. Missing file / bad YAML / empty doc surface
# as a clear failure message instead of a bare traceback.
_assert_policy() {
  python3 - "$POLICY_FILE" <<PY
import sys
import yaml

path = sys.argv[1]
try:
    with open(path) as f:
        policy = yaml.safe_load(f)
except FileNotFoundError:
    print(f"FAIL: policy file not found: {path}", file=sys.stderr)
    sys.exit(1)
except yaml.YAMLError as e:
    print(f"FAIL: policy file is not valid YAML: {e}", file=sys.stderr)
    sys.exit(1)

if policy is None:
    print("FAIL: policy file parsed to nothing (empty document)", file=sys.stderr)
    sys.exit(1)

$1

if not ok:
    print("FAIL: assertion did not hold", file=sys.stderr)
    sys.exit(1)
PY
}

@test "policy/gate-policy.yml exists and parses as YAML" {
  run _assert_policy "ok = True"
  [ "$status" -eq 0 ]
}

@test "all four required gate categories (tests, quality, security, docs) are present" {
  run _assert_policy "
names = {c.get('name') for c in policy.get('categories', [])}
ok = {'tests', 'quality', 'security', 'docs'} <= names
"
  [ "$status" -eq 0 ]
}

@test "tests, quality, security, and docs categories are each marked required: true" {
  run _assert_policy "
cats = {c.get('name'): c for c in policy.get('categories', [])}
ok = all(cats.get(n, {}).get('required') is True for n in ('tests', 'quality', 'security', 'docs'))
"
  [ "$status" -eq 0 ]
}

@test "security.threshold.min_severity_block is set to high" {
  run _assert_policy "
cats = {c.get('name'): c for c in policy.get('categories', [])}
security = cats.get('security', {})
ok = security.get('threshold', {}).get('min_severity_block') == 'high'
"
  [ "$status" -eq 0 ]
}

@test "at least one exemption is declared and every exemption has a description" {
  run _assert_policy "
exemptions = policy.get('exemptions', [])
ok = len(exemptions) > 0 and all(bool((e.get('description') or '').strip()) for e in exemptions)
"
  [ "$status" -eq 0 ]
}

@test "bypass.requires is set and is not none" {
  run _assert_policy "
bypass = policy.get('bypass', {})
ok = bypass.get('requires') not in (None, 'none', '')
"
  [ "$status" -eq 0 ]
}

@test "bypass.must_record includes both actor and reason" {
  run _assert_policy "
must_record = policy.get('bypass', {}).get('must_record', [])
ok = 'actor' in must_record and 'reason' in must_record
"
  [ "$status" -eq 0 ]
}
