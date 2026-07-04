#!/usr/bin/env bash
#
# scripts/check-bypass-record.sh
#
# T022 (FR-006, SC-001): the record-completeness gate behind "any bypass of
# a required gate MUST be recorded, attributed to a named person, and
# justified in writing; silent bypass MUST NOT be possible" (FR-006) / "100%
# of merges into main ... pass the required gates or carry a recorded,
# attributed, written justification — zero silent bypasses" (SC-001).
#
# THIS SCRIPT IS THE RECORD-COMPLETENESS GATE ONLY. It answers exactly one
# question: given a bypass record, is it acceptable under
# policy/gate-policy.yml's `bypass` block? It does not detect that a gate
# was bypassed, does not know how to merge a PR, and does not decide who is
# allowed to invoke `admin-override` — that detection-and-demand wiring
# (recognizing a bypass event on a real PR and requiring this script pass
# before allowing the bypass merge) is CI-integration/branch-protection
# wiring, completed on real CI, same division of responsibility as
# check-docs-required.sh not producing its own changed-files list and
# security-baseline.sh not invoking a scanner itself.
#
# Reads three fields from policy/gate-policy.yml's `bypass` block (never
# hardcoded — a future policy change to any of them is honored
# automatically, no script edit required):
#   bypass.allowed        bool.  If not exactly "true", EVERY bypass is
#                          rejected, regardless of record content — a
#                          complete record is not permission to bypass when
#                          policy disallows bypass outright.
#   bypass.requires       string. Informational only (echoed in output);
#                          this script does not verify who requested the
#                          bypass or that they hold that role — that is a
#                          review/branch-protection concern, not a text
#                          field this script can authenticate.
#   bypass.must_record    list of field names (e.g. [actor, reason]) that
#                          MUST each be present AND non-empty in the record
#                          for it to pass. THE LIST ITSELF, not its
#                          contents, is what makes a field required — add a
#                          field to policy and it becomes required here
#                          with no script change.
#
# -----------------------------------------------------------------------
# BYPASS RECORD FORMAT (this script's input contract)
# -----------------------------------------------------------------------
# A plain-text file (or stdin via '-') of 'key: value' lines, one field per
# line — deliberately not YAML: no nesting, no lists, no quoting rules, so
# a human filling out a bypass justification (or a CI step templating one)
# needs zero tooling beyond a text editor. Blank lines and lines starting
# with '#' are ignored (comment/spacing convention shared with
# check-docs-required.sh's --changed-files list). Everything after the
# first ':' on a line is the value, verbatim except for trimmed
# leading/trailing whitespace — a reason may itself contain colons (e.g.
# "reason: outage 2026-07-04 14:32 UTC"). A line with no ':' is ignored (not
# a recognized field). A field repeated more than once: the last occurrence
# wins.
#
# Example (a complete, passing record under the default policy):
#   actor: alice
#   reason: prod registry outage; gate infrastructure itself down, verified
#     via status page
#
# Usage:
#   check-bypass-record.sh --record <path|-> [--policy <path/to/gate-policy.yml>]
#
#   --record  Path to a bypass record file ('key: value' lines; '#'
#             comments and blank lines ignored). Use '-' to read from
#             stdin. Required.
#   --policy  Path to gate-policy.yml supplying bypass.allowed,
#             bypass.requires, and bypass.must_record. Optional; default:
#             policy/gate-policy.yml (resolved relative to the current
#             working directory) — same convention as run-gate.sh's
#             --policy.
#
# Exit codes:
#   0  pass   — bypass.allowed is true, and every field in
#               bypass.must_record is present and non-empty in the record.
#   1  fail   — bypass.allowed is not true (any bypass rejected), or at
#               least one required field is missing or empty.
#   2  usage  — bad/missing arguments, or the record/policy file does not
#               exist.
#
# Dependencies: yq (mikefarah v4) — the same parser every other
# policy-consuming script in this repo uses (run-gate.sh,
# tests/unit/test_gate_policy.bats).
#
# Output: a `BYPASS_RECORD_RESULT ...` line (verdict + context), and on
# failure, `BYPASS_RECORD_MESSAGE:` lines naming what failed and what
# passing requires (FR-005 convention — same as run-gate.sh's
# `RUN_GATE_MESSAGE:` lines). On success, one `BYPASS_RECORD_LOG:` line per
# required field, echoing its value — the "attributable + logged" half of
# FR-006/SC-001: the fact of the bypass, who did it, and why is never
# silent.

set -euo pipefail

readonly EXIT_PASS=0
readonly EXIT_FAIL=1
readonly EXIT_USAGE=2

readonly DEFAULT_POLICY_FILE="policy/gate-policy.yml"

usage() {
  cat >&2 <<'USAGE'
Usage: check-bypass-record.sh --record <path|-> [--policy <path/to/gate-policy.yml>]

  --record  Path to a bypass record file ('key: value' lines, one field
            per line; '#' comments and blank lines ignored). Use '-' to
            read the record from stdin. Required.
  --policy  Path to gate-policy.yml providing bypass.allowed,
            bypass.requires, and bypass.must_record. Optional; default:
            policy/gate-policy.yml.

Record format (full definition in this script's header comment):
'key: value' lines. Every field named in policy's bypass.must_record must
be present and non-empty. If policy's bypass.allowed is not true, every
bypass is rejected regardless of record content.
USAGE
}

record_source=""
policy_file="${DEFAULT_POLICY_FILE}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --record)
      if [ "$#" -lt 2 ]; then
        echo "::error::check-bypass-record: --record requires a value." >&2
        usage
        exit "${EXIT_USAGE}"
      fi
      record_source="${2:-}"
      shift 2
      ;;
    --policy)
      if [ "$#" -lt 2 ]; then
        echo "::error::check-bypass-record: --policy requires a value." >&2
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
      echo "::error::check-bypass-record: unknown argument '$1'." >&2
      usage
      exit "${EXIT_USAGE}"
      ;;
  esac
done

if [ -z "${record_source}" ]; then
  echo "::error::check-bypass-record: --record is required." >&2
  usage
  exit "${EXIT_USAGE}"
fi

if [ "${record_source}" != "-" ] && [ ! -f "${record_source}" ]; then
  echo "::error::check-bypass-record: bypass record not found: '${record_source}'." >&2
  exit "${EXIT_USAGE}"
fi

if [ ! -f "${policy_file}" ]; then
  echo "::error::check-bypass-record: policy file not found: '${policy_file}'." >&2
  exit "${EXIT_USAGE}"
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "::error::check-bypass-record: 'yq' (mikefarah v4) is required but not found on PATH." >&2
  exit "${EXIT_USAGE}"
fi

# Trim leading/trailing whitespace (same pattern as check-docs-required.sh).
_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

# --- read policy: bypass.allowed, bypass.requires, bypass.must_record -------
#
# Deliberately NOT `yq -e`: yq's `-e` treats a YAML `false` (and `null`) as
# "no match" and exits non-zero even though it printed the value first —
# which would make "bypass.allowed: false" indistinguishable from "key
# absent" via exit code alone. Plain `yq` always exits 0 here and prints
# the literal scalar (or "null" if absent), which we compare as text below
# — the only reliable way to read a boolean that may legitimately be false.

allowed_raw="$(yq '.bypass.allowed' "${policy_file}")"
requires_raw="$(yq '.bypass.requires' "${policy_file}")"

# must_record: sourced from policy at runtime — NOT a hardcoded [actor,
# reason] pair. A policy whose must_record adds a third field makes that
# field required here with no script change.
must_record_fields=()
while IFS= read -r field || [ -n "${field:-}" ]; do
  [ -z "${field}" ] && continue
  must_record_fields+=("${field}")
done < <(yq '.bypass.must_record[]' "${policy_file}")

# --- bypass.allowed: false (or missing/null) rejects EVERY bypass -----------
#
# Fail-safe default: anything other than the literal "true" is treated as
# "bypass not allowed" — a malformed or absent bypass.allowed must not be
# read as permission.

if [ "${allowed_raw}" != "true" ]; then
  echo "BYPASS_RECORD_RESULT check=bypass-record verdict=fail allowed=${allowed_raw}"
  echo "::error::check-bypass-record: bypass rejected — policy declares bypass.allowed=${allowed_raw}; no bypass is permitted." >&2
  echo "BYPASS_RECORD_MESSAGE: check 'bypass-record' failed — policy/gate-policy.yml's bypass.allowed is '${allowed_raw}', not 'true'."
  echo "BYPASS_RECORD_MESSAGE: to pass, do not attempt a bypass while it is disallowed; resolve the underlying gate failure instead, or have policy/gate-policy.yml explicitly set bypass.allowed: true before requesting one."
  exit "${EXIT_FAIL}"
fi

# --- parse the record: 'key: value' lines into parallel arrays --------------

record_keys=()
record_values=()
while IFS= read -r raw_line || [ -n "${raw_line:-}" ]; do
  line="$(_trim "${raw_line}")"
  [ -z "${line}" ] && continue
  case "${line}" in "#"*) continue ;; esac
  case "${line}" in
    *:*)
      key="$(_trim "${line%%:*}")"
      value="$(_trim "${line#*:}")"
      record_keys+=("${key}")
      record_values+=("${value}")
      ;;
    *)
      : # no ':' — not a recognized 'key: value' line, ignored
      ;;
  esac
done < <(if [ "${record_source}" = "-" ]; then cat; else cat "${record_source}"; fi)

# Look up the last-seen value for a given key. Sets RECORD_LOOKUP_FOUND (0
# if seen at all, 1 if never seen) and RECORD_LOOKUP_VALUE (its value, ""
# if never seen).
_record_value_for() {
  local want="$1"
  RECORD_LOOKUP_FOUND=1
  RECORD_LOOKUP_VALUE=""
  local i
  for i in "${!record_keys[@]}"; do
    if [ "${record_keys[${i}]}" = "${want}" ]; then
      RECORD_LOOKUP_FOUND=0
      RECORD_LOOKUP_VALUE="${record_values[${i}]}"
    fi
  done
}

# --- validate every required field is present and non-empty ----------------

missing_fields=()
empty_fields=()
for field in "${must_record_fields[@]}"; do
  _record_value_for "${field}"
  if [ "${RECORD_LOOKUP_FOUND}" -ne 0 ]; then
    missing_fields+=("${field}")
  elif [ -z "${RECORD_LOOKUP_VALUE}" ]; then
    empty_fields+=("${field}")
  fi
done

must_record_csv=""
if [ "${#must_record_fields[@]}" -gt 0 ]; then
  must_record_csv="$(
    IFS=,
    echo "${must_record_fields[*]}"
  )"
fi

if [ "${#missing_fields[@]}" -gt 0 ] || [ "${#empty_fields[@]}" -gt 0 ]; then
  missing_csv=""
  if [ "${#missing_fields[@]}" -gt 0 ]; then
    missing_csv="$(
      IFS=,
      echo "${missing_fields[*]}"
    )"
  fi
  empty_csv=""
  if [ "${#empty_fields[@]}" -gt 0 ]; then
    empty_csv="$(
      IFS=,
      echo "${empty_fields[*]}"
    )"
  fi

  echo "BYPASS_RECORD_RESULT check=bypass-record verdict=fail missing=${missing_csv} empty=${empty_csv} must_record=${must_record_csv}"
  echo "::error::check-bypass-record: bypass rejected — required field(s) not satisfied in the bypass record." >&2
  if [ -n "${missing_csv}" ]; then
    echo "BYPASS_RECORD_MESSAGE: required field(s) missing entirely from the record: ${missing_csv}."
  fi
  if [ -n "${empty_csv}" ]; then
    echo "BYPASS_RECORD_MESSAGE: required field(s) present but empty in the record: ${empty_csv}."
  fi
  echo "BYPASS_RECORD_MESSAGE: to pass, a valid bypass record must supply a non-empty 'key: value' line for every field in policy/gate-policy.yml's bypass.must_record (currently: ${must_record_csv}) — e.g. 'actor: <your-username>' and 'reason: <why this bypass is necessary>'."
  exit "${EXIT_FAIL}"
fi

# --- pass: echo the record to the log (attributable + logged) --------------

echo "BYPASS_RECORD_RESULT check=bypass-record verdict=pass requires=${requires_raw} must_record=${must_record_csv}"
for field in "${must_record_fields[@]}"; do
  _record_value_for "${field}"
  echo "BYPASS_RECORD_LOG: ${field}='${RECORD_LOOKUP_VALUE}'"
done
exit "${EXIT_PASS}"
