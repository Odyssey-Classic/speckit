# Implementation Plan: CI/CD Pipeline, Versioning & Release Process

**Branch**: `001-cicd-pipeline-plan` | **Date**: 2026-06-07 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-cicd-pipeline/spec.md`

## Summary

Deliver a centrally-governed, language-agnostic CI/CD foundation for the
multi-repository, multi-application Odyssey project. The mechanism is a set of
**reusable CI workflows and a versioned gate policy hosted in this (speckit)
repository**, which every other repository adopts by reference — pinning a
policy version and supplying only language-specific adapter commands, never
bespoke gate logic. The same foundation provides per-application,
git-tag-driven semantic versioning; a single-action release process that
produces signed, verifiable, atomically-published artifacts with generated
release notes; and a spec-traceability gate that links every PR back to the
central spec that authorized it.

Interoperability between applications and the operation of any live service
are explicitly out of scope (per spec Clarifications) and are not designed
here.

## Technical Context

**Language/Version**: Policy and tooling are language-agnostic by design.
Reference/adapter implementations target the languages in play today (Go 1.18
in `server`) and a generic adapter contract for the rest (web client,
admin tools, world registry — languages TBD per repo). Tooling glue is
POSIX shell + the CI platform's native expression language.

**Primary Dependencies**: GitHub Actions (reusable workflows via
`workflow_call` + composite actions); `git` for version derivation
(`git describe`); platform-native artifact attestation (GitHub Artifact
Attestations / Sigstore cosign) for signing & verification; GitHub Releases as
the publication surface.

**Storage**: None beyond git history, git tags, and the CI platform's
release/artifact store. No database.

**Testing**: Workflow/tooling tests via the CI platform's own runners —
shell-level unit tests (e.g., `bats` or equivalent) for version-derivation and
release scripts, plus end-to-end "harness repo" jobs that exercise a caller
workflow against deliberately failing and passing fixtures.

**Target Platform**: GitHub-hosted (and self-hosted-capable) CI runners,
Linux primary. Consumed by repositories under a single GitHub organization
(`Odyssey-Classic/*`); any repo currently outside the org is expected to move
under it.

**Project Type**: CI/CD infrastructure + governance tooling (not application
code). Artifacts are reusable workflows, composite actions, policy
configuration, and documentation hosted centrally and consumed cross-repo.

**Performance Goals**: No wall-clock SLA (per spec SC-003 — speed is a tuning
target, not a promise). Design goal: gates add negligible overhead beyond the
adapter command's own runtime; gate feedback is automatic and definitive.

**Constraints**:
- Must hold for **any number** of repositories and applications under the
  single Odyssey organization (spec Assumptions; [[never-assume-repo-count]]).
- Adoption MUST be configuration-only: zero bespoke gate logic per repo
  (SC-005).
- Strict SemVer; pre-1.0 releases must visibly disclaim compatibility
  (FR-011).
- Releases must be reproducible and atomically published (FR-012, FR-016).
- Secure-by-default: no plaintext secrets in config; least-privilege CI
  tokens; signing keys never exported (Constitution VIII).

**Scale/Scope**: Small contributor base today; design must not assume it.
Initial rollout: this repo (governed/docs-only profile) + `server` (Go
profile) as the proving ground, then the remaining application repos.

## Repositories Affected

Per Constitution → Development Workflow → Cross-repository coordination. This
feature is built almost entirely in `speckit`; consuming repos adopt by
reference (configuration-only), so `server` is the sole proving-ground consumer
changed within this feature's scope.

| Order | Repository | What changes here | Depends on / coordinates with |
|-------|------------|-------------------|-------------------------------|
| 1 | speckit | The entire central foundation: reusable workflows (`gate`, `release`, `spec-trace`), composite actions, `policy/`, `adapters/`, `docs/cicd/`, `tests/`. Dogfoods its own gate via the `docs-only` profile. | — (self-contained) |
| 2 | server | Proving-ground caller workflows (`.github/workflows/ci.yml` + `release.yml`, `adapter: go`) + branch protection (T050). | Consumes speckit's reusable workflows (order 1) |

**Future consumers (not changed here):** `client`, `proto`, `admin-tools`, and
`registry` adopt the same gates by reference as they come online —
configuration-only onboarding tracked as their own work, not part of 001's core
scope (see T053 and "Deferred to /speckit-tasks or later").

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevance | Verdict |
|-----------|-----------|---------|
| **IV. Spec-First, Centrally Governed** | Plan derives from the ratified, merged spec (PR #2); reusable workflows live centrally in this repo, satisfying "defined once, centrally" (FR-003, FR-020). | ✅ Pass |
| **IV. Cross-repo declaration (v1.1.0)** | Multi-repo feature — the `## Repositories Affected` section declares affected repos + coordination order, and tasks attribute to a repo (default `speckit`; T050 → `server`). | ✅ Pass |
| **V. Tested to Be Trusted** | The gate tooling itself is tested (fixture repos, shell unit tests); the foundation is what *enforces* tests in every other repo. A gate change requires a failing-then-passing fixture. | ✅ Pass |
| **VI. Docs as a Feature** | Onboarding guide, gate-policy reference, versioning policy, and release runbook ship as part of this feature, not after. | ✅ Pass |
| **VII. Simplicity & YAGNI** | Reuses platform-native primitives (Actions reusable workflows, GitHub Releases, native attestations) instead of bespoke infrastructure. No custom CI server, no custom artifact registry. | ✅ Pass |
| **VIII. Secure by Default** | Security gate (dependency + secret + SAST), signed artifacts, least-privilege tokens, secure-default templates with documented opt-out for any exception. | ✅ Pass |
| **III. Open Ecosystem / Licensing** | Quality gate includes a license-declaration check: each repo must declare its AGPL-core vs Apache-edge side (Constitution III). Reusable workflows are edge tooling → Apache-2.0. | ✅ Pass |
| **II / I / Engine Identity** | Indirect: releases must stay hobbyist-installable (verifiable artifacts, plain install path). No conflict. | ✅ Pass |

**Result**: No violations. Complexity Tracking not required (see note there).

## Project Structure

### Documentation (this feature)

```text
specs/001-cicd-pipeline/
├── plan.md              # This file (/speckit-plan output)
├── research.md          # Phase 0 output — decisions & rationale
├── data-model.md        # Phase 1 output — policy/version/release entities
├── quickstart.md        # Phase 1 output — adopt-gates / cut-release / verify
├── contracts/           # Phase 1 output — interface contracts
│   ├── reusable-workflow-interface.md
│   ├── version-derivation.md
│   ├── release-metadata.schema.md
│   ├── gate-policy.schema.md
│   └── spec-reference.md
├── checklists/
│   └── requirements.md  # Spec quality checklist (from /speckit-specify)
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

The deliverables live centrally in **this repository** and are consumed by
every other repo by reference. Consuming repos add only thin caller files.

```text
# Central (this repo: Odyssey-Classic/speckit) — the governed source of truth
.github/
└── workflows/
    ├── gate.yml             # Reusable: orchestrates required gate categories
    ├── release.yml          # Reusable: build → notes → sign → atomic publish
    └── spec-trace.yml       # Reusable: PR spec-reference check
.github/actions/
├── derive-version/          # Composite: git-tag → SemVer (+ pre-1.0 disclaimer)
├── run-gate/                # Composite: invoke a language adapter, normalize result
├── attest-and-verify/       # Composite: sign artifact + emit verification material
└── compose-release-notes/   # Composite: changes/upgrade/breaking from PR metadata

policy/
├── gate-policy.yml          # Central gate categories, thresholds, exemptions (versioned)
├── versioning-policy.md     # SemVer rules; pre-1.0 disclosure requirement
└── VERSION                  # Policy version pinned by consumers (FR-018, FR-020)

adapters/                    # Per-ecosystem adapter command definitions (uniform contract)
├── go/                      # test / lint / security / docs commands for Go
├── node/                    # …for web client / JS-TS tooling
└── _template/               # Starter for a new ecosystem (configuration, not code)

docs/cicd/
├── onboarding.md            # Adopt the standard gates in a new repo (SC-005)
├── release-runbook.md       # Cut and hotfix a release (SC-004)
└── verification.md          # How operators verify artifact authenticity (FR-014)

tests/
├── fixtures/                # Pass/fail sample changes per gate category
└── e2e/                     # Harness-repo jobs exercising caller workflows

# Consuming repo (e.g., Odyssey-Classic/server) — thin, generated from template
.github/workflows/
├── ci.yml                   # `uses: Odyssey-Classic/speckit/.github/workflows/gate.yml@vX`
└── release.yml              # `uses: …/release.yml@vX` with adapter: go
```

**Structure Decision**: Central-hub model. All gate/version/release logic and
policy live in `speckit` (the constitutionally-designated central governance
repo), versioned and pinned by consumers. Consuming repositories contain only
declarative caller workflows naming their adapter — making adoption pure
configuration (SC-005) and keeping a single point of policy truth (FR-003,
FR-020). All repos live under the one Odyssey organization, so consumption
uses simple `Odyssey-Classic/<repo>/.github/workflows/file.yml@ref`
references.

## Complexity Tracking

> No constitution violations — this section is intentionally empty.

One deliberate design choice worth recording (not a violation): logic is
centralized in reusable workflows rather than copied per repo. This is the
*simpler* option under Principle VII (one source of truth, configuration-only
adoption), not added complexity, so it needs no justification entry.

## Deferred to /speckit-tasks or later

- **Release retraction / yank policy** for a release later found defective
  (flagged during clarification as plan-level). Addressed in research.md as a
  decision; task breakdown handled by `/speckit-tasks`.
- **Per-repo adapter authoring** for languages beyond Go/Node as those
  application repos come online (the adapter contract is defined here; each
  instance is configuration).
