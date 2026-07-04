#!/usr/bin/env bash
#
# .github/actions/run-gate/security-baseline.sh
#
# T018 (FR-004, research.md D12): the pure classification core behind the
# security gate's newly-introduced-vs-pre-existing vulnerability diff.
# Given a set of CURRENT findings (this branch/PR) and a set of BASELINE
# findings (the target branch, e.g. main), plus the policy's
# min_severity_block threshold, this script:
#
#   1. Classifies every CURRENT finding as:
#        - "new"         — its fingerprint does not appear in BASELINE
#        - "preexisting" — its fingerprint also appears in BASELINE
#      Classification is by FINGERPRINT ONLY (see FORMAT below) — never by
#      severity — because the same underlying issue can be re-scored
#      between scans; the fingerprint is what makes two findings "the same
#      finding".
#   2. BLOCKS (exits non-zero) iff at least one "new" finding's severity is
#      >= the threshold.
#   3. SURFACES (reports, never blocks on its own) every "preexisting"
#      finding and every "new" finding below the threshold.
#
# This is FR-004 + research.md D12's fairness rule made independently
# testable from any real scanner: "don't punish a contributor for a
# vulnerability they didn't introduce, while still preventing new risk."
# run-gate.sh (T017/T018 SEAM) is the caller that wires this into the
# security gate category when a baseline is available; see its header
# comment for how (and when) that wiring is actually active.
#
# -----------------------------------------------------------------------
# FINDING FORMAT — the contract security-scanning adapters must emit
# -----------------------------------------------------------------------
# One finding per line, tab-separated:
#
#   <severity>\t<fingerprint>
#
#   severity     One of: low, medium, high, critical (case-insensitive on
#                input; normalized to lowercase in output). Ordering for
#                threshold comparison: low < medium < high < critical.
#   fingerprint  An opaque, stable string identifying THIS finding, stable
#                across repeated scans of the same underlying issue (e.g.
#                "CVE-2024-1234|left-pad@1.0.0" or a scanner-native rule ID
#                + location). Should not contain a tab or newline. May
#                contain spaces.
#
# Blank lines (empty or whitespace-only) and lines starting with '#' are
# ignored (comments / spacing) — this keeps fixtures and hand-authored
# baselines readable.
#
# This is intentionally the smallest possible contract: translating a real
# scanner's native output (SARIF, JSON, ...) into this format is the job of
# a future scanner adapter (T050 and later CI-integration work) — this
# script never parses a scanner's native format itself.
#
# Usage:
#   security-baseline.sh --current <path> --baseline <path> \
#                         --min-severity <low|medium|high|critical>
#
# Exit codes:
#   0  pass   — no newly-introduced finding at/above the threshold. (Pre-
#               existing and below-threshold findings may still be present
#               — they are surfaced in the output, never blocking.)
#   1  block  — at least one newly-introduced finding at/above threshold.
#   2  usage  — bad/missing arguments, a non-existent file, or a malformed
#               finding line (missing fingerprint field, unknown severity
#               word).
#
# Output: one `SECURITY_BASELINE_FINDING ...` line per current finding,
# then a single `SECURITY_BASELINE_RESULT ...` summary line — both
# structured key=value, parseable with grep/awk without a YAML/JSON parser
# (same convention as run-gate.sh's `RUN_GATE_RESULT` line).

set -euo pipefail

readonly EXIT_PASS=0
readonly EXIT_BLOCK=1
readonly EXIT_USAGE=2

usage() {
  cat >&2 <<'USAGE'
Usage: security-baseline.sh --current <path> --baseline <path> --min-severity <low|medium|high|critical>

  --current       Path to the current findings file (this branch/PR).
  --baseline      Path to the baseline findings file (target branch).
  --min-severity  Policy severity threshold (gate-policy.yml
                  security.threshold.min_severity_block). A newly-
                  introduced finding at or above this severity blocks;
                  everything else (pre-existing, or new-but-below-
                  threshold) is surfaced only.

Finding file format: one "<severity>\t<fingerprint>" per line (severity:
low|medium|high|critical). Blank lines and lines starting with '#' are
ignored. See this script's header comment for the full contract.
USAGE
}

# Severity ordering for threshold comparison: low < medium < high < critical.
severity_rank() {
  case "$1" in
    low) echo 0 ;;
    medium) echo 1 ;;
    high) echo 2 ;;
    critical) echo 3 ;;
    *) return 1 ;;
  esac
}

current_file=""
baseline_file=""
min_severity=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --current)
      current_file="${2:-}"
      shift 2
      ;;
    --baseline)
      baseline_file="${2:-}"
      shift 2
      ;;
    --min-severity)
      min_severity="${2:-}"
      shift 2
      ;;
    -h | --help)
      usage
      exit "${EXIT_PASS}"
      ;;
    *)
      echo "::error::security-baseline: unknown argument '$1'." >&2
      usage
      exit "${EXIT_USAGE}"
      ;;
  esac
done

if [ -z "${current_file}" ] || [ -z "${baseline_file}" ] || [ -z "${min_severity}" ]; then
  echo "::error::security-baseline: --current, --baseline, and --min-severity are all required." >&2
  usage
  exit "${EXIT_USAGE}"
fi

if [ ! -f "${current_file}" ]; then
  echo "::error::security-baseline: current findings file not found: '${current_file}'." >&2
  exit "${EXIT_USAGE}"
fi

if [ ! -f "${baseline_file}" ]; then
  echo "::error::security-baseline: baseline findings file not found: '${baseline_file}'." >&2
  exit "${EXIT_USAGE}"
fi

min_severity="$(printf '%s' "${min_severity}" | tr '[:upper:]' '[:lower:]')"
if ! threshold_rank=$(severity_rank "${min_severity}"); then
  echo "::error::security-baseline: unknown --min-severity '${min_severity}' — must be one of low, medium, high, critical." >&2
  exit "${EXIT_USAGE}"
fi

# Build the baseline fingerprint set. Classification is by fingerprint
# only (see FINDING FORMAT above) — the baseline's own severity value is
# not consulted for classification.
declare -A baseline_fingerprints=()
while IFS=$'\t' read -r b_severity b_fingerprint || [ -n "${b_severity:-}" ]; do
  [ -z "${b_severity//[[:space:]]/}" ] && continue
  case "${b_severity}" in "#"*) continue ;; esac
  if [ -z "${b_fingerprint:-}" ]; then
    echo "::error::security-baseline: malformed baseline line (missing fingerprint field): '${b_severity}'." >&2
    exit "${EXIT_USAGE}"
  fi
  baseline_fingerprints["${b_fingerprint}"]=1
done <"${baseline_file}"

total=0
new_count=0
preexisting_count=0
blocking_count=0

while IFS=$'\t' read -r c_severity c_fingerprint || [ -n "${c_severity:-}" ]; do
  [ -z "${c_severity//[[:space:]]/}" ] && continue
  case "${c_severity}" in "#"*) continue ;; esac
  if [ -z "${c_fingerprint:-}" ]; then
    echo "::error::security-baseline: malformed current finding line (missing fingerprint field): '${c_severity}'." >&2
    exit "${EXIT_USAGE}"
  fi

  c_severity_norm="$(printf '%s' "${c_severity}" | tr '[:upper:]' '[:lower:]')"
  if ! c_rank=$(severity_rank "${c_severity_norm}"); then
    echo "::error::security-baseline: unknown severity '${c_severity}' in current finding (fingerprint '${c_fingerprint}') — must be one of low, medium, high, critical." >&2
    exit "${EXIT_USAGE}"
  fi

  total=$((total + 1))

  if [ -n "${baseline_fingerprints[${c_fingerprint}]+set}" ]; then
    classification="preexisting"
    preexisting_count=$((preexisting_count + 1))
    action="surface"
  else
    classification="new"
    new_count=$((new_count + 1))
    if [ "${c_rank}" -ge "${threshold_rank}" ]; then
      action="block"
      blocking_count=$((blocking_count + 1))
    else
      action="surface"
    fi
  fi

  echo "SECURITY_BASELINE_FINDING classification=${classification} severity=${c_severity_norm} fingerprint=${c_fingerprint} action=${action}"
done <"${current_file}"

if [ "${blocking_count}" -gt 0 ]; then
  verdict="block"
else
  verdict="pass"
fi

echo "SECURITY_BASELINE_RESULT verdict=${verdict} threshold=${min_severity} total=${total} new=${new_count} preexisting=${preexisting_count} blocking=${blocking_count}"

if [ "${verdict}" = "block" ]; then
  echo "::error::security-baseline: ${blocking_count} newly-introduced finding(s) at/above severity '${min_severity}' — see SECURITY_BASELINE_FINDING lines with action=block." >&2
  exit "${EXIT_BLOCK}"
fi

exit "${EXIT_PASS}"
