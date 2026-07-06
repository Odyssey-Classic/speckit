# Quickstart & Validation: CI/CD Pipeline, Versioning & Release Process

**Feature**: `specs/001-cicd-pipeline` | **Date**: 2026-06-07

Runnable scenarios that prove the feature works end-to-end. Each maps to spec
acceptance scenarios / success criteria. Implementation details live in
`tasks.md` (next phase); this is the validation guide.

Prerequisites: the central workflows/policy published in `speckit` at a pinned
version (e.g., `policy-v1`); a target consuming repo on GitHub; `gh` CLI;
`cosign` (or `gh attestation`) for verification.

---

## Scenario A — Adopt the gates in a new repository (US1, SC-005)

1. Copy the caller stub from `docs/cicd/onboarding.md` into the target repo:
   `.github/workflows/ci.yml` referencing
   `Odyssey-Classic/speckit/.github/workflows/gate.yml@policy-v1` with
   `adapter:` and `license_side:` set (see
   [contracts/reusable-workflow-interface.md](./contracts/reusable-workflow-interface.md)).
2. Enable branch protection requiring the gate checks.

**Expected**: The repo runs the full gate set with **zero bespoke gate logic**
added — only the caller stub and adapter selection (SC-005). Adoption is
configuration, not design.

## Scenario B — Gates block bad PRs, pass clean ones (US1, SC-001/SC-003)

Open four PRs and observe automatic, definitive results:

| PR | Expected gate result |
|----|----------------------|
| Breaks a test | Blocked; `tests` check fails with which test (US1.1). |
| Introduces a known high-sev dependency | Blocked; `security` names the dependency (US1.2, D12). |
| Has a pre-existing vuln only | Surfaced, **not** blocked (Edge Cases, D12). |
| Clean + approving review | Mergeable (US1.3). |

**Expected**: Every required gate ran automatically with a definitive
pass/fail and no manual trigger (SC-003). Any bypass is attributable and
logged (SC-001, D13).

## Scenario C — Same categories across languages (US1.4)

Repeat Scenario B in a Go repo and a non-Go repo.
**Expected**: identical gate categories (`tests`/`quality`/`security`/`docs`)
enforced in both; only the adapter commands differ (FR-003).

## Scenario D — Version identity (US2, SC-002)

1. Build an untagged commit → version is `X.Y.Z-N-g<sha>` (pre-release).
2. Tag `v0.3.0`, build → version `0.3.0`, **and** output carries the pre-1.0
   "no compatibility promises" notice (FR-011).
3. Ask the running app its version.

**Expected**: each artifact's version uniquely maps to its source commit; the
running app reports the same version (US2.1/2.2, SC-002); pre-1.0 disclaimer
present (US2.4). See
[contracts/version-derivation.md](./contracts/version-derivation.md).

## Scenario E — Cut a release (US3, SC-004)

1. Push tag `v1.0.0` (or `workflow_dispatch` with the version).

**Expected**: a **single triggered action** produces, with no manual
assembly: installable artifact(s), release notes (changes / upgrade steps /
breaking changes), checksums, and signature/provenance — published as one
atomic GitHub Release (SC-004, FR-013/016). A run that fails partway yields
**no** visible release (FR-016). See
[contracts/release-metadata.schema.md](./contracts/release-metadata.schema.md).

## Scenario F — Verify a release as an operator (US3.3, FR-014)

1. Download an artifact + its attestation.
2. Run the verify command from `docs/cicd/verification.md`.

**Expected**: authenticity + provenance verify against the publishing
workflow; a tampered artifact fails verification.

## Scenario G — Hotfix without dragging unreleased work (US3.4, FR-015)

1. Branch from tag `v1.0.0`, apply fix, tag `v1.0.1`, push.

**Expected**: `v1.0.1` releases containing only the fix; unreleased `main`
work is not included (D14).

## Scenario H — Spec traceability (US4, SC-007)

| PR | Expected |
|----|----------|
| References `Spec: 001-cicd-pipeline@spec-001-cicd-pipeline` (a `speckit` git tag/commit) | spec-trace passes. |
| No reference, no exemption | Omission surfaced to reviewer, not silently passed (FR-017). |
| `maintenance` label | Passes via documented exemption. |

See [contracts/spec-reference.md](./contracts/spec-reference.md).

## Scenario I — Policy version & drift (FR-018/020)

1. Bump central policy to `policy-v2`; leave a consumer pinned at `policy-v1`.

**Expected**: the consumer keeps running `v1` unchanged (immutable pin); the
drift audit lists it as behind. Re-pinning to `v2` is the upgrade.

---

**Done when** all scenarios A–I pass against the proving-ground repos
(`speckit` docs-only profile + `server` Go profile), demonstrating every
mandatory user story and success criterion.
