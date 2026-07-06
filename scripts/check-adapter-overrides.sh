#!/usr/bin/env bash
#
# scripts/check-adapter-overrides.sh
#
# T016 review fix: the FR-003 adapter-override rejection, extracted out of
# gate.yml's `setup` job (previously an inline `yq` walk in a `run:` step)
# so it is independently unit-testable with bats
# (tests/unit/test_check_adapter_overrides.bats) without a GitHub Actions
# runner — same rationale as run-gate.sh living outside action.yml
# (.github/actions/run-gate/action.yml's header comment).
#
# FR-003 (Constitution Principle V): an adapter (adapters/<ecosystem>/
# adapter.yml) supplies only HOW to satisfy a gate category, never WHETHER.
# Thresholds, exemptions, bypass rules, and policy itself are decided once,
# centrally, in policy/gate-policy.yml. This script rejects an adapter file
# that declares any key, at any depth, that is one of those decisions in
# disguise.
#
# MATCHING RULE (case-insensitive, substring, any depth):
#   Every map key in the document — at any depth, including a key only
#   reachable through a YAML anchor/merge (`<<: *anchor`; the anchor's own
#   definition is still a literal mapping node somewhere in the document
#   tree, so walking the whole tree finds it regardless of where it's
#   merged in) or nested under a list item — is lowercased and checked
#   for whether it EQUALS OR CONTAINS one of: threshold, exemption,
#   bypass, policy, override. Equality alone is not enough: a
#   case-differing key (`Threshold`) or a compound key (`policy_override`,
#   `sev_threshold`) is exactly as disallowed as the bare word, and an
#   exact-match-only guard would silently let those through.
#
# Verified against all four real adapters (_template, go, node, docs-only):
# none contain any of these tokens in any key at any depth, so this guard
# does not false-positive against a real adapter's legitimate hook-shape
# keys (adapter, hooks, id, ecosystem, description, run, test, lint,
# security, docs, build, version-embed).
#
# Usage:
#   check-adapter-overrides.sh <path/to/adapter.yml>
#
# Exit codes:
#   0  pass   — no disallowed key found anywhere in the document.
#   1  fail   — at least one disallowed key found.
#   2  usage  — wrong argument count, or the adapter file does not exist.
#
# Dependencies: yq (mikefarah v4) — the same parser every other
# policy/adapter-consuming script in this repo uses (run-gate.sh,
# tests/unit/test_gate_policy.bats).
#
# Output: on failure, an `::error::` line (gate.yml's own convention) and
# `ADAPTER_OVERRIDE_MESSAGE:` lines naming the offending key(s), what
# failed, and what passing requires (FR-005 convention — same as
# run-gate.sh's `RUN_GATE_MESSAGE:` lines).

set -euo pipefail

readonly EXIT_PASS=0
readonly EXIT_FAIL=1
readonly EXIT_USAGE=2

# Substrings (not exact names), matched against every key's lowercased
# form. Plural forms (exemptions, overrides) are already covered by their
# singular substring; listed here as the authoritative token set (FR-003).
readonly DISALLOWED_TOKENS="threshold exemption bypass policy override"

usage() {
  cat >&2 <<'USAGE'
Usage: check-adapter-overrides.sh <path/to/adapter.yml>

Rejects (non-zero exit) an adapter file that declares any key, at any
depth, whose lowercased name equals or contains one of: threshold,
exemption, bypass, policy, override (FR-003, Constitution Principle V).
An adapter supplies only HOW to satisfy a gate category, never WHETHER —
those decisions live solely, centrally, in policy/gate-policy.yml.
USAGE
}

if [ "$#" -ne 1 ]; then
  echo "::error::check-adapter-overrides: expected exactly one argument (adapter file path), got $#." >&2
  usage
  exit "${EXIT_USAGE}"
fi

adapter_file="$1"

if [ -z "${adapter_file}" ] || [ ! -f "${adapter_file}" ]; then
  echo "::error::check-adapter-overrides: adapter file not found: '${adapter_file}'." >&2
  exit "${EXIT_USAGE}"
fi

# Walk every mapping node in the document (`..`), collect every key at
# every depth (`select(tag == "!!map") | keys`), unique. This traverses
# into list items and anchor definitions alike — `..` is a full document
# walk, not scoped to any particular top-level branch.
found_keys=$(yq '[.. | select(tag == "!!map") | keys | .[]] | unique | .[]' "${adapter_file}")

bad=""
while IFS= read -r key; do
  [ -z "${key}" ] && continue
  lower_key=$(printf '%s' "${key}" | tr '[:upper:]' '[:lower:]')
  for token in ${DISALLOWED_TOKENS}; do
    case "${lower_key}" in
      *"${token}"*)
        bad="${bad}${key} "
        break
        ;;
    esac
  done
done <<<"${found_keys}"

if [ -n "${bad}" ]; then
  echo "::error::check-adapter-overrides: adapter '${adapter_file}' declares disallowed key(s): ${bad}— an adapter supplies only HOW to satisfy a gate category, never WHETHER (FR-003, Constitution Principle V). Thresholds, exemptions, bypass rules, and policy live solely in policy/gate-policy.yml. Remove ${bad}from the adapter; propose any policy change centrally instead." >&2
  echo "ADAPTER_OVERRIDE_MESSAGE: adapter '${adapter_file}' failed the override guard on key(s): ${bad}(matched case-insensitively, by substring, at any depth)."
  echo "ADAPTER_OVERRIDE_MESSAGE: to pass, remove ${bad}from the adapter — thresholds, exemptions, bypass rules, and policy live solely, centrally, in policy/gate-policy.yml (FR-003, Constitution Principle V)."
  exit "${EXIT_FAIL}"
fi

echo "check-adapter-overrides: adapter '${adapter_file}' contains no policy-override keys — OK."
exit "${EXIT_PASS}"
