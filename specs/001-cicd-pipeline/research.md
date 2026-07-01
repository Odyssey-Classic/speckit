# Phase 0 Research: CI/CD Pipeline, Versioning & Release Process

**Feature**: `specs/001-cicd-pipeline` | **Date**: 2026-06-07

This document records the technical decisions that resolve the open choices in
the Technical Context. The spec deliberately granted "reasonable defaults"
latitude; each decision below is the default chosen, with rationale and the
alternatives weighed. No `NEEDS CLARIFICATION` remained blocking after the
three clarification sessions.

## Context discovered

- All repositories live (or will live) under **a single GitHub organization**
  (`Odyssey-Classic`); any repo currently elsewhere is expected to move under
  the org. Plans and tooling assume one org owner, not a cross-owner spread.
- Repositories span **multiple languages** (Go 1.18 server today; web client
  and others to come). No CI exists in the server repo yet — greenfield.
- The constitution designates this repo as the central, authoritative spec and
  governance home (Principle IV), which is the natural home for central CI
  policy and reusable workflows.

---

## D1 — CI platform: GitHub Actions reusable workflows

- **Decision**: Use GitHub Actions, with the shared logic packaged as
  **reusable workflows** (`on: workflow_call`) plus **composite actions**,
  hosted in `speckit` and referenced by every other repo via
  `uses: Odyssey-Classic/speckit/.github/workflows/gate.yml@vX`.
- **Rationale**: All repos are on GitHub under one organization. Reusable
  workflows give exactly the "defined once centrally, adopted by reference"
  property the spec demands (FR-003, FR-020) and make adoption
  configuration-only (SC-005). Single-org references keep the `uses:` paths
  simple and access trivial.
- **Alternatives considered**:
  - *Org-level `.github` repo defaults*: viable under a single org, but the
    constitution designates `speckit` as the central governance home
    (Principle IV), so policy + workflows live there rather than in a separate
    `.github` repo. (Org-level *default* workflows remain an option later for
    convenience without changing the source of truth.)
  - *Copied per-repo pipelines*: violates SC-005 (bespoke logic) and FR-003
    (single source of truth).
  - *External CI (CircleCI/GitLab/Jenkins)*: adds infrastructure to run and
    secure, contradicting Principle VII and the hobbyist-affordability ethos.

## D2 — Gate categories and their uniform contract

- **Decision**: Required gate categories are **tests, code quality, security
  (dependencies + secrets + SAST), and documentation** (FR-002, Constitution
  V & VI). Each category is invoked through a uniform **adapter contract**: a
  repo declares, per category, the command(s) for its ecosystem; the central
  `run-gate` action runs them and normalizes pass/fail. Categories and
  blocking thresholds live in central `policy/gate-policy.yml`; only the
  *commands* are per-repo.
- **Rationale**: Keeps categories/thresholds central and identical everywhere
  (FR-003) while letting each language satisfy them its own way — the spec's
  "same categories, different means" requirement.
- **Alternatives considered**: One mega-workflow per language (rejected:
  duplicates policy); a single tool claiming to lint all languages (rejected:
  none covers the heterogeneous set well; couples policy to a vendor).

## D3 — Versioning: git-tag-driven SemVer, per application

- **Decision**: Each application owns its versions via **annotated git tags**
  (`vMAJOR.MINOR.PATCH`). Builds derive their version deterministically with
  `git describe` — a tagged commit builds as that exact version; an untagged
  commit builds as a unique, traceable pre-release (`vX.Y.Z-N-gSHA`). No human
  invents numbers (FR-010). Strict SemVer semantics; **pre-1.0 builds are
  unconditionally stamped with a "no compatibility promises" notice** in
  release notes and `--version` output (FR-011).
- **Rationale**: Tags are language-agnostic and already-present in every repo;
  `git describe` makes version↔source mapping unique and reproducible (FR-008,
  SC-002). Per-app ownership matches the clarified model.
- **Alternatives considered**:
  - *Central version registry/manifest*: rejected during clarification (interop
    is out of scope; apps own their own versions).
  - *Conventional-commits auto-bump (semantic-release)*: useful but opinionated
    and couples the bump to commit message discipline; kept as an optional
    adapter feature, not the base mechanism.

## D4 — Artifact identity & traceability

- **Decision**: Every built artifact **embeds its derived version and commit
  SHA** (build-time injection, e.g. Go `-ldflags -X`), and every running
  application reports it on demand (FR-008, SC-002, US2 scenario 2). A build
  provenance attestation records the source commit and workflow.
- **Rationale**: Makes "what is this and where did it come from" answerable
  from the artifact alone, without external lookup.
- **Alternatives considered**: Version-in-filename only (rejected: lost once
  unpacked/renamed); external build database (rejected: extra infra, single
  point of failure).

## D5 — Release: single triggered action, reproducible, atomic

- **Decision**: A release is triggered by **pushing a SemVer tag** (or
  `workflow_dispatch` with a version), invoking the central `release.yml`
  reusable workflow which: builds reproducibly from that tagged source,
  composes release notes, signs/attests, and publishes **one GitHub Release
  object with all assets attached** (single triggered action → all outputs, no
  manual assembly: SC-004; atomic from consumer view: FR-016). Publication
  fails closed — a partial run never yields a visible Release.
- **Rationale**: GitHub Releases are atomic at the release-object level and are
  the simplest hobbyist-discoverable surface. Tag-triggered keeps it to one
  action.
- **Alternatives considered**: Manual asset upload (rejected: SC-004); custom
  artifact registry (rejected: Principle VII, hobbyist cost).

## D6 — Reproducibility

- **Decision**: Builds pin toolchain versions and dependency lockfiles; the
  release workflow builds **only from the tagged commit** with pinned inputs so
  re-running a version yields functionally identical artifacts (FR-012).
  Provenance attestation captures the inputs.
- **Rationale**: Determinism is required by FR-012 and underpins verification.
- **Alternatives considered**: Best-effort/non-pinned builds (rejected: breaks
  FR-012 and verification trust).

## D7 — Signing & verification

- **Decision**: Use **GitHub Artifact Attestations / Sigstore (cosign,
  keyless OIDC)** to sign artifacts and produce SLSA-style provenance;
  publish checksums alongside. Operators verify with `cosign verify` /
  `gh attestation verify` per a short `docs/cicd/verification.md` (FR-014,
  SC for verifiability).
- **Rationale**: Keyless signing avoids the hobbyist-hostile burden of key
  custody, while giving cryptographic authenticity + provenance. Native to the
  platform → Principle VII.
- **Alternatives considered**: Long-lived GPG keys (rejected: key-management
  burden, exfiltration risk); checksums only (rejected: integrity without
  authenticity).

## D8 — Release notes generation

- **Decision**: Compose notes from **merged-PR titles/labels between the
  previous and current tag**, grouped into user-visible changes, upgrade
  steps, and breaking changes; a curated section may be appended. Pre-1.0
  releases always include the compatibility disclaimer (FR-013, FR-011).
- **Rationale**: PR metadata already exists and is the lowest-friction source
  for accurate, per-application notes.
- **Alternatives considered**: Hand-written changelog only (rejected:
  SC-004 manual assembly); strict conventional-commits (kept optional, not
  required, to avoid imposing commit discipline project-wide).

## D9 — Spec-traceability gate

- **Decision**: A `spec-trace` reusable workflow checks each PR for a
  reference to a central spec ID + version (e.g., a `Spec: 001-cicd-pipeline@<ver>`
  trailer or PR-body field), enforced via a PR template. PRs labeled with a
  documented **exemption** (e.g., `maintenance`) pass; otherwise the omission
  is surfaced to reviewers, not silently passed (FR-017, SC-007).
- **Rationale**: Cheap, reviewer-visible enforcement of Principle IV
  traceability that scales as contributors grow.
- **Alternatives considered**: Hard block on every PR (rejected: too rigid for
  routine maintenance — spec calls for "surfaced unless exempted"); manual
  review only (rejected: not enforceable/repeatable).

## D10 — Policy versioning & drift detection

- **Decision**: The reusable workflows + `policy/gate-policy.yml` are versioned
  with **release tags on `speckit`** (`policy-vX` / repo SemVer). Consumers pin
  a version in their `uses:` ref; the pinned ref *is* the recorded policy
  version each repo implements (FR-018, FR-020). A lightweight audit
  (workflow listing each consumer's pinned ref) makes drift visible.
- **Rationale**: The pin is both adoption and the drift signal — no separate
  bookkeeping.
- **Alternatives considered**: Floating `@main` ref (rejected: non-reproducible,
  no drift signal); separate version-tracking file per repo (rejected:
  duplicates the pin, drifts from reality).

## D11 — Onboarding a new repository

- **Decision**: `docs/cicd/onboarding.md` + an `adapters/_template/` and caller
  workflow stubs let a new repo adopt the full gate set by copying the stub and
  naming its adapter — **zero bespoke gate logic** (SC-005, FR-019, FR-021).
- **Rationale**: Configuration-only adoption is the measurable success
  criterion; a template is the most direct way to guarantee it.
- **Alternatives considered**: Per-repo hand-rolled pipelines (rejected:
  SC-005); a scaffolding CLI (deferred: YAGNI until repo count makes copy-paste
  painful).

## D12 — Pre-existing vs introduced vulnerabilities

- **Decision**: The security gate **blocks** on newly-introduced
  vulnerabilities at/above the policy severity threshold (default:
  high-and-above) and **surfaces-but-does-not-block** pre-existing ones, by
  diffing findings against a baseline of the target branch (FR-004, spec Edge
  Cases).
- **Rationale**: Honors the spec's fairness rule — don't punish a contributor
  for a vulnerability they didn't introduce — while still preventing new risk.
- **Alternatives considered**: Block on any finding (rejected: blocks unrelated
  PRs, contributor-hostile); ignore pre-existing entirely (rejected: invisible
  risk).

## D13 — Gate bypass accountability

- **Decision**: Required gates are enforced via branch protection. Any bypass
  uses the platform's recorded admin-override / explicit exemption label, which
  is **attributable and logged**; the central policy forbids silent bypass
  (FR-006, SC-001).
- **Rationale**: Bypasses must exist (outages, false positives — Edge Cases)
  but never silently (SC-001's "zero silent bypasses").
- **Alternatives considered**: No bypass at all (rejected: gate outage would
  freeze all merges); informal bypass (rejected: violates SC-001).

## D14 — Hotfix / retraction handling

- **Decision**: Hotfix by branching from the released tag, applying the fix,
  and tagging a new PATCH — releasing the fix without dragging unreleased
  `main` work (FR-015, US3 scenario 4). For a release later found defective:
  publish a corrected higher version and **mark the bad release deprecated**
  (GitHub Release note + flag) rather than deleting it, preserving operators
  already running it.
- **Rationale**: Forward-fix + deprecate is safer than deletion (which breaks
  in-flight downloads and reproducibility).
- **Alternatives considered**: Delete/yank the bad release (rejected: breaks
  operators and the immutability verification relies on).

---

**Outcome**: All Technical Context unknowns resolved. Ready for Phase 1
design.
