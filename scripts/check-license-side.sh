#!/usr/bin/env bash
#
# scripts/check-license-side.sh
#
# T019 (FR-021, Constitution Principle III): the central `quality` gate
# category's license-side declaration check. Constitution III draws
# exactly two lines: the engine core (server + the systems that make a
# world run) is AGPL-3.0, spelled "agpl-core"; the ecosystem edges (client
# SDKs, protocol definitions, creator tooling) are Apache-2.0, spelled
# "apache-edge". Every repository declares which side it sits on; FR-021
# requires the quality gate to verify that declaration exists and is
# valid, and to block a repository that declares no valid side.
#
# gate.yml (T016, not yet authored — see reusable-workflow-interface.md)
# takes `license_side` as one of its two required workflow inputs and is
# expected to pass it straight through to this script as (part of) the
# `quality` category.
#
# THIS SCRIPT IS DELIBERATELY DUMB. It validates the declared VALUE only —
# it never inspects LICENSE files, repo contents, or a charter to infer or
# cross-check the side. The charter (governed centrally in this repo, per
# the constitution's Development Workflow) is the place a side is actually
# recorded and reviewed; re-deriving it here from source would be a second,
# divergent source of truth. A wrong-but-validly-spelled declaration is a
# review/charter problem this gate cannot and does not try to catch.
#
# Usage:
#   check-license-side.sh --license-side <agpl-core|apache-edge>
#   check-license-side.sh <agpl-core|apache-edge>            # positional form
#   LICENSE_SIDE=<agpl-core|apache-edge> check-license-side.sh   # env fallback,
#     used only when neither a flag nor a positional argument is given.
#     Named to match gate.yml's own `license_side` workflow input.
#
# Precedence when more than one is given: --license-side / positional
# argument wins over the LICENSE_SIDE env var.
#
# Exit codes:
#   0  pass   — declared value is exactly "agpl-core" or "apache-edge".
#   1  fail   — value is empty, unknown, or wrong-case (e.g. "AGPL-Core",
#               "gpl"). Case and spelling are significant: these are the
#               two exact strings the reusable-workflow-interface contract,
#               every adapter, and every charter use — silently accepting
#               a near-miss would let a typo'd declaration slip through as
#               if it were a real one.
#   2  usage  — an unrecognized command-line argument.
#
# Output: a `LICENSE_SIDE_RESULT ...` line (category, check, verdict,
# declared value), and on failure, `LICENSE_SIDE_MESSAGE:` lines naming the
# category, what failed, and what passing requires (FR-005) — same
# convention as .github/actions/run-gate/run-gate.sh's `RUN_GATE_MESSAGE:`
# lines.

set -euo pipefail

readonly EXIT_PASS=0
readonly EXIT_FAIL=1
readonly EXIT_USAGE=2

readonly VALID_AGPL_CORE="agpl-core"
readonly VALID_APACHE_EDGE="apache-edge"

usage() {
  cat >&2 <<'USAGE'
Usage: check-license-side.sh [--license-side <agpl-core|apache-edge>] [<agpl-core|apache-edge>]

  --license-side  The declared license side (flag form).
  (positional)    The declared license side, if --license-side is not given.
  LICENSE_SIDE    Env var fallback, used only when neither of the above is
                  given (matches gate.yml's own `license_side` input name).

Exactly one of "agpl-core" or "apache-edge" is valid (Constitution
Principle III). Empty, unknown, or wrong-case values (e.g. "AGPL-Core",
"gpl") fail.
USAGE
}

license_side=""
license_side_set=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --license-side)
      license_side="${2:-}"
      license_side_set=1
      shift 2
      ;;
    -h | --help)
      usage
      exit "${EXIT_PASS}"
      ;;
    -*)
      echo "::error::check-license-side: unknown argument '$1'." >&2
      usage
      exit "${EXIT_USAGE}"
      ;;
    *)
      license_side="$1"
      license_side_set=1
      shift
      ;;
  esac
done

# Fall back to the env var only when neither a flag nor a positional
# argument was given at all (not merely when the given value is empty —
# an explicitly empty --license-side "" is still a deliberate empty
# declaration and must fail, not silently fall back to the env var).
if [ "${license_side_set}" -eq 0 ]; then
  license_side="${LICENSE_SIDE:-}"
fi

if [ "${license_side}" != "${VALID_AGPL_CORE}" ] && [ "${license_side}" != "${VALID_APACHE_EDGE}" ]; then
  display_value="${license_side}"
  if [ -z "${display_value}" ]; then
    display_value="(empty)"
  fi
  echo "LICENSE_SIDE_RESULT category=quality check=license-side verdict=fail declared='${display_value}'"
  echo "::error::check-license-side: quality gate failed — no valid license side declared." >&2
  echo "LICENSE_SIDE_MESSAGE: category 'quality' failed check 'license-side' on declared value '${display_value}'."
  echo "LICENSE_SIDE_MESSAGE: to pass, declare exactly one of: '${VALID_AGPL_CORE}' (engine core, AGPL-3.0) or '${VALID_APACHE_EDGE}' (ecosystem edge, Apache-2.0) — case-sensitive, per Constitution Principle III."
  exit "${EXIT_FAIL}"
fi

echo "LICENSE_SIDE_RESULT category=quality check=license-side verdict=pass declared='${license_side}'"
exit "${EXIT_PASS}"
