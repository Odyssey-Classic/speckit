#!/usr/bin/env bash
#
# .github/actions/run-gate/run-gate.sh
#
# Core, unit-testable logic behind the `run-gate` composite action
# (action.yml, T017). gate.yml (T016) calls the composite action once per
# required gate category from policy/gate-policy.yml; the composite action
# is a thin wrapper around this script (see action.yml's header comment for
# why the logic lives here instead of inline `run:` steps).
#
# Given an adapter file, a gate category, and a policy file, this script:
#   1. Looks up the category in the policy (is it declared, is it
#      required, what is its threshold) via yq.
#   2. Resolves the category -> hook mapping and reads that hook's `run:`
#      command from the adapter via yq (tests->test, quality->lint,
#      security->security, docs->docs; see adapters/_template/adapter.yml).
#   3. Executes the hook command, capturing its exit code and output.
#   4. Normalizes the result into a single verdict: prints a structured,
#      parseable `RUN_GATE_RESULT ...` line (category, hook, verdict,
#      exit_code) and, on failure, a `RUN_GATE_MESSAGE:` block stating
#      which category failed, on what, and what passing requires (FR-005).
#
# Usage:
#   run-gate.sh --adapter <path/to/adapter.yml> \
#               --category <tests|quality|security|docs> \
#               [--policy <path/to/gate-policy.yml>]   # default: policy/gate-policy.yml
#
# Exit codes:
#   0  pass    — the hook exited 0.
#   1  fail    — the hook exited non-zero (a real gate failure).
#   2  usage   — bad/missing command-line arguments.
#   3  config  — unknown category, category not declared in policy, adapter
#                or policy file not found, hook missing/empty in adapter.
#                (Distinct from 1 only for this script's own testability;
#                a caller treats any non-zero the same way: check failed.)
#
# Dependencies: yq (mikefarah v4) — the same parser the policy/adapter
# contracts are validated with elsewhere in this repo (see
# tests/unit/test_gate_policy.bats), avoiding a two-parser divergence on
# these governance artifacts.

set -euo pipefail

readonly EXIT_PASS=0
readonly EXIT_FAIL=1
readonly EXIT_USAGE=2
readonly EXIT_CONFIG=3

readonly DEFAULT_POLICY_FILE="policy/gate-policy.yml"

# Resolved so the D12 baseline-diff call below (security category only)
# can find security-baseline.sh (T018) sitting alongside this script,
# regardless of the caller's current working directory or how this script
# was invoked (absolute path from action.yml, relative path from bats).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

usage() {
  cat >&2 <<'USAGE'
Usage: run-gate.sh --adapter <path> --category <tests|quality|security|docs> [--policy <path>]

  --adapter   Path to an ecosystem adapter.yml (adapters/_template/adapter.yml
              documents the contract). Required.
  --category  One of: tests, quality, security, docs — a gate-policy.yml
              category name. Required.
  --policy    Path to gate-policy.yml. Optional; default: policy/gate-policy.yml
              (resolved relative to the current working directory).
USAGE
}

adapter_file=""
category=""
policy_file="${DEFAULT_POLICY_FILE}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --adapter)
      if [ "$#" -lt 2 ]; then
        echo "::error::run-gate: --adapter requires a value." >&2
        usage
        exit "${EXIT_USAGE}"
      fi
      adapter_file="${2:-}"
      shift 2
      ;;
    --category)
      if [ "$#" -lt 2 ]; then
        echo "::error::run-gate: --category requires a value." >&2
        usage
        exit "${EXIT_USAGE}"
      fi
      category="${2:-}"
      shift 2
      ;;
    --policy)
      if [ "$#" -lt 2 ]; then
        echo "::error::run-gate: --policy requires a value." >&2
        usage
        exit "${EXIT_USAGE}"
      fi
      policy_file="${2:-}"
      shift 2
      ;;
    -h | --help)
      usage
      exit "${EXIT_PASS}"
      ;;
    *)
      echo "::error::run-gate: unknown argument '$1'." >&2
      usage
      exit "${EXIT_USAGE}"
      ;;
  esac
done

if [ -z "${adapter_file}" ] || [ -z "${category}" ]; then
  echo "::error::run-gate: --adapter and --category are both required." >&2
  usage
  exit "${EXIT_USAGE}"
fi

if [ -z "${policy_file}" ]; then
  policy_file="${DEFAULT_POLICY_FILE}"
fi

if [ ! -f "${adapter_file}" ]; then
  echo "::error::run-gate: adapter file not found: '${adapter_file}'." >&2
  exit "${EXIT_CONFIG}"
fi

if [ ! -f "${policy_file}" ]; then
  echo "::error::run-gate: policy file not found: '${policy_file}'." >&2
  exit "${EXIT_CONFIG}"
fi

# Category -> hook mapping (adapters/_template/adapter.yml "REQUIRED HOOK
# KEYS"). Every adapter must declare all six hooks; only four map to a
# gate-policy category — build/version-embed are release-path concerns, not
# invoked by run-gate.
case "${category}" in
  tests) hook_name="test" ;;
  quality) hook_name="lint" ;;
  security) hook_name="security" ;;
  docs) hook_name="docs" ;;
  *)
    echo "::error::run-gate: unknown category '${category}' — must be one of: tests, quality, security, docs." >&2
    exit "${EXIT_CONFIG}"
    ;;
esac

# Step 1: the category must actually be declared in the policy. gate.yml
# (T016) is expected to only ever invoke required categories, but a typo'd
# or drifted category name must fail loudly here too, not silently no-op.
if ! yq -e ".categories[] | select(.name == \"${category}\")" "${policy_file}" >/dev/null 2>&1; then
  echo "::error::run-gate: category '${category}' is not declared in policy file '${policy_file}'." >&2
  exit "${EXIT_CONFIG}"
fi

required=$(yq -e ".categories[] | select(.name == \"${category}\") | .required" "${policy_file}" 2>/dev/null || echo "unknown")
echo "run-gate: category '${category}' policy.required=${required} (informational — gate.yml decides which categories to invoke; run-gate always evaluates the one it is given)." >&2

# Step 2: resolve the hook's run: command from the adapter.
if ! run_cmd=$(yq -e ".hooks.${hook_name}.run" "${adapter_file}" 2>/dev/null); then
  echo "::error::run-gate: adapter '${adapter_file}' has no hook '${hook_name}' (mapped from category '${category}'). Every adapter must declare all six hooks — see adapters/_template/adapter.yml." >&2
  exit "${EXIT_CONFIG}"
fi

if [ -z "${run_cmd//[[:space:]]/}" ]; then
  echo "::error::run-gate: adapter '${adapter_file}' hook '${hook_name}' has an empty run: command. A hook that genuinely doesn't apply must still be a documented no-op (e.g. ': # no-op — reason'), never blank — see adapters/_template/adapter.yml." >&2
  exit "${EXIT_CONFIG}"
fi

description=$(yq -e ".hooks.${hook_name}.description" "${adapter_file}" 2>/dev/null || echo "(no description provided)")

# -----------------------------------------------------------------------
# Security category ONLY: source the blocking severity threshold from the
# policy AT RUNTIME. Carried review note — this MUST come from
# gate-policy.yml's threshold.min_severity_block, never be trusted from an
# adapter-hardcoded flag, since adapters supply only the *means* of
# scanning, never the *threshold* (FR-003). Exported so the hook command
# below can read/apply it.
#
# >>> SEAM FOR T018 (newly-introduced vs. pre-existing baseline diff,
#     research.md D12, policy threshold.preexisting: surface) <<<
# STATUS: the classification itself is DONE — security-baseline.sh (T018)
# is a standalone, independently unit-tested (test_security_baseline.bats)
# script that, given a current-findings file and a baseline-findings file
# (both in its documented "<severity>\t<fingerprint>" format), blocks iff a
# NEWLY INTRODUCED finding is at/above RUN_GATE_MIN_SEVERITY_BLOCK and
# surfaces (never blocks on its own) everything pre-existing or below
# threshold — exactly `preexisting: surface`.
#
# What is STILL NOT CI-wired: producing that baseline requires scanning
# the TARGET branch (e.g. main) — a checkout/fetch-of-the-base-ref step
# that only a real CI job can do (gate.yml, T050), not this standalone
# script. So this script does not scan anything itself; it only looks for
# two env vars a CI-integration step would set once T050 lands:
#
#   RUN_GATE_SECURITY_CURRENT_FINDINGS_FILE   current branch/PR findings
#   RUN_GATE_SECURITY_BASELINE_FINDINGS_FILE  target-branch baseline findings
#
# When BOTH are set and point at existing files, the D12 diff below is
# genuinely active: the security verdict comes from security-baseline.sh,
# not from the hook's raw exit code. When they are absent (true today,
# until T050's CI wiring lands), this script HONESTLY falls back to the
# hook's own exit code as the entire verdict — the pre-T018 behavior,
# logged clearly below so nobody mistakes the fallback for D12 diffing
# being active. Nothing here should be read as claiming pre-existing/new
# discrimination is happening when the two findings files were never
# supplied.
# -----------------------------------------------------------------------
if [ "${category}" = "security" ]; then
  if ! min_severity_block=$(yq -e '.categories[] | select(.name == "security") | .threshold.min_severity_block' "${policy_file}" 2>/dev/null); then
    echo "::error::run-gate: policy '${policy_file}' security category has no threshold.min_severity_block set (required by FR-004)." >&2
    exit "${EXIT_CONFIG}"
  fi
  if ! preexisting_mode=$(yq -e '.categories[] | select(.name == "security") | .threshold.preexisting' "${policy_file}" 2>/dev/null); then
    echo "::error::run-gate: policy '${policy_file}' security category has no threshold.preexisting set." >&2
    exit "${EXIT_CONFIG}"
  fi
  export RUN_GATE_MIN_SEVERITY_BLOCK="${min_severity_block}"
  export RUN_GATE_SECURITY_PREEXISTING_MODE="${preexisting_mode}"
  echo "run-gate: security threshold sourced from policy '${policy_file}': min_severity_block=${RUN_GATE_MIN_SEVERITY_BLOCK}, preexisting=${RUN_GATE_SECURITY_PREEXISTING_MODE}." >&2
fi

# Step 3: execute the hook, capturing exit code + combined output. set +e
# around the call so `set -e` above doesn't abort before we get to inspect
# the exit code ourselves.
set +e
hook_output=$(bash -c "${run_cmd}" 2>&1)
hook_exit=$?
set -e

# Step 3.5: security category ONLY — D12 baseline diff (T018). See the SEAM
# comment above for what this does and does not do. This block only
# decides WHETHER security-baseline.sh's classification is invoked; the
# classification logic itself lives entirely in that script (independently
# unit-tested by tests/unit/test_security_baseline.bats).
if [ "${category}" = "security" ]; then
  current_findings_file="${RUN_GATE_SECURITY_CURRENT_FINDINGS_FILE:-}"
  baseline_findings_file="${RUN_GATE_SECURITY_BASELINE_FINDINGS_FILE:-}"
  if [ -n "${current_findings_file}" ] && [ -n "${baseline_findings_file}" ] \
    && [ -f "${current_findings_file}" ] && [ -f "${baseline_findings_file}" ]; then
    echo "run-gate: D12 baseline diff ACTIVE for security category (current='${current_findings_file}', baseline='${baseline_findings_file}') — security-baseline.sh's verdict, not the hook's raw exit code, decides pass/fail." >&2
    # The classifier's "preexisting: surface" behavior is not itself
    # configurable — it is the only mode research.md D12 defines, and the
    # only value the policy schema currently declares. Flag (not fail) if
    # a future policy ever says otherwise, so a schema change doesn't
    # silently stop matching this script's fixed behavior.
    if [ "${preexisting_mode}" != "surface" ]; then
      echo "::warning::run-gate: policy threshold.preexisting='${preexisting_mode}' but security-baseline.sh only implements 'surface' semantics — pre-existing findings will still be surfaced-not-blocked regardless." >&2
    fi
    set +e
    baseline_output=$("${SCRIPT_DIR}/security-baseline.sh" \
      --current "${current_findings_file}" \
      --baseline "${baseline_findings_file}" \
      --min-severity "${min_severity_block}" 2>&1)
    baseline_exit=$?
    set -e
    hook_output="${hook_output}
${baseline_output}"
    hook_exit="${baseline_exit}"
  else
    echo "run-gate: D12 baseline diff NOT active for security category (RUN_GATE_SECURITY_CURRENT_FINDINGS_FILE / RUN_GATE_SECURITY_BASELINE_FINDINGS_FILE not both set to existing files) — falling back to the hook's raw exit code as the entire verdict. Newly-introduced vs. pre-existing is NOT being distinguished in this run. See SEAM FOR T018 comment above." >&2
  fi
fi

# Step 4: normalize into a single verdict.
if [ "${hook_exit}" -eq 0 ]; then
  echo "RUN_GATE_RESULT category=${category} hook=${hook_name} verdict=pass exit_code=0"
  if [ -n "${hook_output}" ]; then
    printf '%s\n' "${hook_output}"
  fi
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      echo "category=${category}"
      echo "verdict=pass"
    } >>"${GITHUB_OUTPUT}"
  fi
  exit "${EXIT_PASS}"
else
  echo "RUN_GATE_RESULT category=${category} hook=${hook_name} verdict=fail exit_code=${hook_exit}"
  echo "::error::run-gate: category '${category}' failed."
  echo "RUN_GATE_MESSAGE: category '${category}' failed, running hook '${hook_name}' (${description})."
  echo "RUN_GATE_MESSAGE: command exited ${hook_exit}. Output:"
  printf '%s\n' "${hook_output}" | sed 's/^/RUN_GATE_MESSAGE:   /'
  echo "RUN_GATE_MESSAGE: to pass '${category}', the '${hook_name}' hook requires: ${description} (must exit 0)."
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      echo "category=${category}"
      echo "verdict=fail"
    } >>"${GITHUB_OUTPUT}"
  fi
  exit "${EXIT_FAIL}"
fi
