#!/usr/bin/env bash
# scripts/lint-composite-actions.sh
#
# actionlint does not check a composite action's `runs.steps[].run` shell
# content: it validates action metadata (inputs/outputs/branding/runner
# name) only, and only once some workflow references the action via
# `uses:` — a standalone action.yml with no consuming workflow yet (e.g.
# freshly authored, before its caller workflow lands) is not linted by
# actionlint at all. See https://github.com/rhysd/actionlint/blob/main/docs/checks.md
# ("actionlint checks action metadata files which are used by workflows
# ... Note that `steps` in Composite action's metadata is not checked at
# this point.").
#
# This script closes that gap so composite-action shell is held to the
# same bar as every other script in this repo (Makefile `lint` target):
# for every `.github/actions/*/action.yml` (or `.yaml`), it extracts each
# `runs.steps[]` entry whose `shell:` is a bash variant and pipes its
# `run:` script straight through shellcheck.
#
# Usage: scripts/lint-composite-actions.sh

set -euo pipefail

shopt -s nullglob
files=(.github/actions/*/action.yml .github/actions/*/action.yaml)

if [ "${#files[@]}" -eq 0 ]; then
  echo "no composite actions yet — skipping"
  exit 0
fi

status=0

for f in "${files[@]}"; do
  step_count=$(yq '.runs.steps | length' "$f")
  i=0
  while [ "$i" -lt "$step_count" ]; do
    step_shell=$(STEP_INDEX="$i" yq '.runs.steps[env(STEP_INDEX)].shell // ""' "$f")
    case "$step_shell" in
      bash | "bash "*)
        step_name=$(STEP_INDEX="$i" yq '.runs.steps[env(STEP_INDEX)].name // "(unnamed step)"' "$f")
        echo "-- $f :: step $i ($step_name), shell: $step_shell"
        if ! STEP_INDEX="$i" yq '.runs.steps[env(STEP_INDEX)].run' "$f" | shellcheck -s bash -; then
          status=1
        fi
        ;;
    esac
    i=$((i + 1))
  done
done

exit "$status"
