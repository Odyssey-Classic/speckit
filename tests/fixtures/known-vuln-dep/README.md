# Gate fixture: `known-vuln-dep`

**Intended gate outcome**: BLOCKED. Driving category: **`security`**
(a newly-introduced finding at/above `security.threshold.min_severity_block:
high`, per `policy/gate-policy.yml` and FR-004/research.md D12).

This fixture's project introduces a **real, independently-verified**
known-vulnerable dependency that a real adapter security hook can detect:

| Variant | Dependency | Real finding (verified locally, see below) |
|---|---|---|
| [`go/`](./go/) | `golang.org/x/text@v0.3.5`, called via `language.ParseAcceptLanguage` | `govulncheck ./...` reports `GO-2022-1059` and `GO-2021-0113` (exit 3). |
| [`node/`](./node/) | `lodash@4.17.15` | `npm audit --audit-level=high` reports a **high**-severity Prototype Pollution finding (`GHSA-p6mc-m468-83gw`; exit 1). |

Both variants otherwise pass `tests`/`quality`/`docs` cleanly, isolating
`security` as the sole reason the gate blocks (US1.2: "Introduces a known
high-sev dependency -> Blocked; `security` names the dependency").

## Why this fixture also ships synthetic `findings/` files

`policy/gate-policy.yml`'s security category distinguishes a
**newly-introduced** finding (blocks) from a **pre-existing** one
(surfaced only) — FR-004, research.md D12. That classification is fully
implemented and unit-tested (`security-baseline.sh`,
`tests/unit/test_security_baseline.bats`, T018), but **wiring a real
scanner's live output into that classifier — checking out the PR's target
branch to produce a baseline, and translating `govulncheck`/`npm audit`
output into the `<severity>\t<fingerprint>` contract — is T050's
still-open proving-ground rollout, not yet CI-wired into `gate.yml`**
(see `.github/workflows/gate.yml`'s own "NOT YET WIRED HERE" header
comment and `run-gate.sh`'s "SEAM FOR T018" comment). Today, absent that
wiring, `gate.yml`'s security leg would fall back to the hook's raw exit
code — which does demonstrate a real, live scanner finding (see the table
above) but does **not**, by itself, distinguish new-vs-pre-existing.

So this fixture's `findings/` directory supplies the two inputs that seam
already accepts (`RUN_GATE_SECURITY_CURRENT_FINDINGS_FILE`,
`RUN_GATE_SECURITY_BASELINE_FINDINGS_FILE`) — hand-authored, not real
scanner output, exactly the same convention as
`tests/fixtures/security-baseline/*.findings` (T014) — so
`tests/e2e/gate-e2e.yml` (T015) can exercise the *already-implemented*
classifier deterministically today, independent of whichever scanner
binaries happen to be on a given runner. `go-current.findings` /
`node-current.findings` each carry one `high` finding matching the real
dependency above; `go-baseline.findings` / `node-baseline.findings` are
empty — this PR is what introduces the finding, so it classifies as
**new** and, at/above the `high` threshold, **blocks**. Contrast with
`../preexisting-vuln-only/findings/`, whose baseline already carries the
identical fingerprint.

Exercised by `tests/e2e/gate-e2e.yml` (T015) — see that file's header for
the full static-vs-CI-only breakdown.
