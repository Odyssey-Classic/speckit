#!/usr/bin/env bash
#
# scripts/check-docs-required.sh
#
# T020 (FR-002, Constitution Principle VI "Docs as a Feature"): the central
# `docs` gate category's check that a user-facing change ships with docs.
# The constitution is explicit: "A feature without its creator- and/or
# player-facing documentation is unfinished and MUST NOT be considered
# complete." This script is the automated, testable core of that rule.
#
# gate.yml (T016, not yet authored) is expected to invoke this script as
# the `docs` category, supplying the PR's changed-files list and whatever
# exemption signal (if any) it has already determined applies (e.g. a
# documented PR label). Producing the changed-files list itself (a
# checkout/diff-against-base-ref step) is CI-integration wiring that only a
# real workflow run can do — not this script's job, same division of
# responsibility as security-baseline.sh (T018) being handed findings
# files rather than invoking a scanner itself.
#
# -----------------------------------------------------------------------
# THE RULE (this is the full, authoritative definition — nowhere else)
# -----------------------------------------------------------------------
# A changed path is NON-user-facing (does not, on its own, require a docs
# change) iff it falls under one of these prefixes:
#
#   docs/**       already documentation
#   tests/**      test-only changes
#   .github/**    CI/workflow/action plumbing
#   specs/**      spec-kit governance artifacts (spec/plan/tasks/etc.)
#
# Every other path is USER-FACING.
#
# A changed path is a DOCS file iff it falls under docs/** OR matches
# **/*.md (any Markdown file, anywhere in the tree — e.g. a README.md
# living next to the code it documents).
#
# Verdict:
#   FAIL iff: at least one changed path is user-facing
#             AND no changed path is a docs file
#             AND no exemption signal was given.
#   PASS otherwise — including: no changed paths at all; every changed
#     path falls under a non-user-facing prefix; at least one changed path
#     is a docs file; or an exemption signal was given.
#
# This rule deliberately does not try to detect "is this docs change
# actually relevant to that user-facing change" — like run-gate's hooks,
# it is a bright-line presence check, not a semantic reviewer; reviewers
# still read the diff (Development Workflow, "Review").
#
# Usage:
#   check-docs-required.sh --changed-files <path>  [--exempt]
#   check-docs-required.sh --changed-files -        [--exempt]   # read stdin
#
#   --changed-files  Path to a file listing changed paths, one per line,
#                     relative to the repo root (the same shape `git diff
#                     --name-only` produces). Use '-' to read the list from
#                     stdin instead. Blank lines and lines starting with
#                     '#' are ignored (comments/spacing — same convention
#                     as security-baseline.sh's finding-file format).
#                     Required.
#   --exempt          Optional boolean flag. Its presence signals that an
#                     exemption for this change has already been
#                     determined upstream (e.g. gate.yml observed a
#                     documented PR label such as "docs-exempt"). This
#                     script does not itself decide what qualifies for an
#                     exemption or validate a label's legitimacy — it only
#                     honors whatever signal its caller passed, exactly
#                     like run-gate.sh sources its security threshold from
#                     policy rather than deciding one itself.
#
# Exit codes:
#   0  pass   — see rule above.
#   1  fail   — user-facing change(s) present, no docs file among the
#               changes, and not exempt.
#   2  usage  — --changed-files missing, or its file does not exist.
#
# Output: a `DOCS_REQUIRED_RESULT ...` line (verdict + counts), and on
# failure, `DOCS_REQUIRED_MESSAGE:` lines naming the category, what failed
# (which user-facing paths triggered it), and what passing requires
# (FR-005) — same convention as run-gate.sh's `RUN_GATE_MESSAGE:` lines.

set -euo pipefail

readonly EXIT_PASS=0
readonly EXIT_FAIL=1
readonly EXIT_USAGE=2

usage() {
  cat >&2 <<'USAGE'
Usage: check-docs-required.sh --changed-files <path|-> [--exempt]

  --changed-files  Path to a file listing changed paths (one per line;
                    '#' comments and blank lines ignored), or '-' to read
                    the list from stdin. Required.
  --exempt         Optional. Presence signals an upstream-determined
                    exemption (e.g. a documented PR label) — honored as-is,
                    not itself validated by this script.

Rule (full definition in this script's header comment): FAIL iff at least
one changed path is user-facing (outside docs/**, tests/**, .github/**,
specs/**) AND no changed path is a docs file (docs/** or **/*.md) AND no
--exempt was given. PASS otherwise.
USAGE
}

changed_files_source=""
exempt=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --changed-files)
      changed_files_source="${2:-}"
      shift 2
      ;;
    --exempt)
      exempt=1
      shift
      ;;
    -h | --help)
      usage
      exit "${EXIT_PASS}"
      ;;
    *)
      echo "::error::check-docs-required: unknown argument '$1'." >&2
      usage
      exit "${EXIT_USAGE}"
      ;;
  esac
done

if [ -z "${changed_files_source}" ]; then
  echo "::error::check-docs-required: --changed-files is required." >&2
  usage
  exit "${EXIT_USAGE}"
fi

if [ "${changed_files_source}" != "-" ] && [ ! -f "${changed_files_source}" ]; then
  echo "::error::check-docs-required: changed-files list not found: '${changed_files_source}'." >&2
  exit "${EXIT_USAGE}"
fi

total=0
user_facing_count=0
docs_count=0
# First user-facing path seen, kept only for the FR-005 failure message —
# naming ALL of them would be more thorough, but the single worst offender
# is enough to make the failure concrete without an unbounded message body.
first_user_facing=""

while IFS= read -r path || [ -n "${path:-}" ]; do
  # trim leading/trailing whitespace so hand-authored fixtures with
  # incidental indentation still parse correctly.
  trimmed="${path#"${path%%[![:space:]]*}"}"
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
  [ -z "${trimmed}" ] && continue
  case "${trimmed}" in "#"*) continue ;; esac

  total=$((total + 1))

  case "${trimmed}" in
    docs/* | tests/* | .github/* | specs/*)
      : # non-user-facing prefix
      ;;
    *)
      user_facing_count=$((user_facing_count + 1))
      if [ -z "${first_user_facing}" ]; then
        first_user_facing="${trimmed}"
      fi
      ;;
  esac

  case "${trimmed}" in
    docs/* | *.md)
      docs_count=$((docs_count + 1))
      ;;
  esac
done < <(if [ "${changed_files_source}" = "-" ]; then cat; else cat "${changed_files_source}"; fi)

if [ "${user_facing_count}" -gt 0 ] && [ "${docs_count}" -eq 0 ] && [ "${exempt}" -eq 0 ]; then
  echo "DOCS_REQUIRED_RESULT category=docs check=docs-required verdict=fail total=${total} user_facing=${user_facing_count} docs=${docs_count} exempt=false"
  echo "::error::check-docs-required: docs gate failed — user-facing change with no accompanying docs." >&2
  echo "DOCS_REQUIRED_MESSAGE: category 'docs' failed check 'docs-required' on user-facing path '${first_user_facing}' (and ${user_facing_count} user-facing path(s) total) with 0 docs file(s) among the ${total} changed path(s)."
  echo "DOCS_REQUIRED_MESSAGE: to pass, either add a docs change (a path under docs/** or any **/*.md file) covering this change, or apply the documented exemption signal for changes that genuinely need none."
  exit "${EXIT_FAIL}"
fi

exempt_label="false"
if [ "${exempt}" -eq 1 ]; then
  exempt_label="true (upstream exemption signal honored)"
fi
echo "DOCS_REQUIRED_RESULT category=docs check=docs-required verdict=pass total=${total} user_facing=${user_facing_count} docs=${docs_count} exempt=${exempt_label}"
exit "${EXIT_PASS}"
