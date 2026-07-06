#!/usr/bin/env bats
#
# T016 review fix: bats unit test for scripts/check-adapter-overrides.sh —
# the FR-003 adapter-override guard extracted out of gate.yml's inline `yq`
# walk (previously untestable without a GitHub Actions runner) so it is
# independently unit-testable, same rationale as run-gate.sh (T017,
# action.yml's header comment).
#
# What this guard must do (FR-003, Constitution Principle V — an adapter
# supplies only HOW to satisfy a gate category, never WHETHER):
#   - all four real adapters (_template, go, node, docs-only) pass clean —
#     proves the guard has no false positives against real hook-shape keys
#     (adapter, hooks, id, ecosystem, description, run, test, lint,
#     security, docs, build, version-embed).
#   - a disallowed key (threshold(s), exemption(s), bypass, policy,
#     override(s)) is rejected no matter where/how it appears:
#       (a) nested under a list item
#       (b) reachable only via a YAML anchor/merge key (`<<: *anchor`)
#       (c) capitalized differently (case-insensitive match: `Threshold`)
#       (d) compound (substring match: `policy_override`, `sev_threshold`)

setup() {
  REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
  SCRIPT="${REPO_ROOT}/scripts/check-adapter-overrides.sh"
}

# --- real adapters: no false positives ---------------------------------------

@test "adapters/_template/adapter.yml passes the override guard" {
  run "$SCRIPT" "${REPO_ROOT}/adapters/_template/adapter.yml"
  [ "$status" -eq 0 ]
}

@test "adapters/go/adapter.yml passes the override guard" {
  run "$SCRIPT" "${REPO_ROOT}/adapters/go/adapter.yml"
  [ "$status" -eq 0 ]
}

@test "adapters/node/adapter.yml passes the override guard" {
  run "$SCRIPT" "${REPO_ROOT}/adapters/node/adapter.yml"
  [ "$status" -eq 0 ]
}

@test "adapters/docs-only/adapter.yml passes the override guard" {
  run "$SCRIPT" "${REPO_ROOT}/adapters/docs-only/adapter.yml"
  [ "$status" -eq 0 ]
}

# --- disallowed key: nested under a list item --------------------------------

@test "rejects a disallowed key nested under a list item" {
  cat > "${BATS_TEST_TMPDIR}/adapter-list.yml" <<'EOF'
adapter:
  id: fixture
  ecosystem: fixture
hooks:
  test:
    description: "x"
    run: "y"
    extra:
      - name: foo
        threshold: high
EOF
  run "$SCRIPT" "${BATS_TEST_TMPDIR}/adapter-list.yml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"threshold"* ]]
}

# --- disallowed key: reachable only via a YAML anchor/merge ------------------

@test "rejects a disallowed key reachable only via a YAML anchor/merge key" {
  cat > "${BATS_TEST_TMPDIR}/adapter-anchor.yml" <<'EOF'
adapter:
  id: fixture
  ecosystem: fixture
hooks:
  test:
    <<: &shared
      bypass: true
    description: "x"
    run: "y"
EOF
  run "$SCRIPT" "${BATS_TEST_TMPDIR}/adapter-anchor.yml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"bypass"* ]]
}

# --- disallowed key: capitalized (case-insensitive match) --------------------

@test "rejects a capitalized disallowed key (case-insensitive match): Threshold" {
  cat > "${BATS_TEST_TMPDIR}/adapter-capitalized.yml" <<'EOF'
adapter:
  id: fixture
  ecosystem: fixture
hooks:
  test:
    description: "x"
    run: "y"
    Threshold: high
EOF
  run "$SCRIPT" "${BATS_TEST_TMPDIR}/adapter-capitalized.yml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Threshold"* ]]
}

# --- disallowed key: compound (substring match) ------------------------------

@test "rejects a compound disallowed key: policy_override" {
  cat > "${BATS_TEST_TMPDIR}/adapter-compound-policy.yml" <<'EOF'
adapter:
  id: fixture
  ecosystem: fixture
hooks:
  test:
    description: "x"
    run: "y"
    policy_override: true
EOF
  run "$SCRIPT" "${BATS_TEST_TMPDIR}/adapter-compound-policy.yml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"policy_override"* ]]
}

@test "rejects a compound disallowed key: sev_threshold" {
  cat > "${BATS_TEST_TMPDIR}/adapter-compound-sev.yml" <<'EOF'
adapter:
  id: fixture
  ecosystem: fixture
hooks:
  test:
    description: "x"
    run: "y"
    sev_threshold: high
EOF
  run "$SCRIPT" "${BATS_TEST_TMPDIR}/adapter-compound-sev.yml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"sev_threshold"* ]]
}

# --- clean adapter with none of the tokens anywhere --------------------------

@test "a clean hand-crafted adapter with no disallowed tokens anywhere passes" {
  cat > "${BATS_TEST_TMPDIR}/adapter-clean.yml" <<'EOF'
adapter:
  id: fixture
  ecosystem: fixture
hooks:
  test:
    description: "run the suite"
    run: "make test"
  lint:
    description: "lint"
    run: "make lint"
  security:
    description: "scan"
    run: "make scan"
  docs:
    description: "docs check"
    run: "test -s README.md"
  build:
    description: "build"
    run: "make build"
  version-embed:
    description: "embed version"
    run: "make version-embed"
EOF
  run "$SCRIPT" "${BATS_TEST_TMPDIR}/adapter-clean.yml"
  [ "$status" -eq 0 ]
}

# --- usage errors -------------------------------------------------------------

@test "missing argument is a clear non-zero usage error" {
  run "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "a non-existent adapter file is a clear non-zero usage error" {
  run "$SCRIPT" "${REPO_ROOT}/adapters/does-not-exist/adapter.yml"
  [ "$status" -eq 2 ]
}
