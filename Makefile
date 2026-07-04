# Odyssey CI/CD (feature 001-cicd-pipeline) — root lint/test entrypoints.
#
# `make lint` and `make test` must succeed (exit 0) even when there is
# nothing yet to lint/test — later phases add real workflows, actions, and
# bats suites that these same targets will pick up automatically.

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Shell lint scope: only the directories this feature owns (per plan.md's
# "Source Code (repository root)" structure). This deliberately excludes
# .specify/ (the pre-existing SpecKit framework's own scripts — not part of
# this feature's deliverable, and not ours to fix here) and
# tests/bats-core/ (a vendored third-party copy, linted upstream, not here).
SHELL_LINT_DIRS := .github adapters policy scripts tests/unit tests/fixtures tests/e2e

.PHONY: lint lint-actions lint-composite-actions lint-shell test

lint: lint-actions lint-composite-actions lint-shell

lint-actions:
	@echo "==> actionlint (.github/workflows)"
	@if find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | grep -q .; then \
		actionlint -config-file .github/actionlint.yaml; \
	else \
		echo "no workflow YAML yet — skipping actionlint"; \
	fi
# NOTE: actionlint only validates a composite action's *metadata*
# (inputs/outputs/branding/runner name), and only once some workflow
# references it via `uses:` — it does not parse a standalone action.yml at
# all, and does not check `runs.steps[].run` shell content even when a
# workflow does reference it (see docs/cicd/secure-defaults.md and
# scripts/lint-composite-actions.sh's header comment for the upstream
# citation). `lint-composite-actions` below is what actually holds
# composite-action shell to the shellcheck bar in the meantime.

lint-composite-actions:
	@echo "==> shellcheck (composite action run: steps — actionlint doesn't check these)"
	@scripts/lint-composite-actions.sh

lint-shell:
	@echo "==> shellcheck"
	@files=$$(find $(SHELL_LINT_DIRS) -type f \( -name '*.sh' -o -name '*.bash' \) 2>/dev/null); \
	if [ -n "$$files" ]; then \
		shellcheck $$files; \
	else \
		echo "no shell scripts yet — skipping shellcheck"; \
	fi

test:
	@echo "==> bats (tests/unit)"
	@if [ -x tests/bats-core/bin/bats ] && find tests/unit -name '*.bats' 2>/dev/null | grep -q .; then \
		tests/bats-core/bin/bats -r tests/unit; \
	else \
		echo "no bats tests yet — skipping"; \
	fi
