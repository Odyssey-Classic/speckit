# Phase 1 Data Model: CI/CD Pipeline, Versioning & Release Process

**Feature**: `specs/001-cicd-pipeline` | **Date**: 2026-06-07

The "data" here is configuration and metadata, not runtime application state.
Entities below are derived from the spec's Key Entities, refined with the
Phase 0 decisions. Field types are conceptual (the concrete schemas live in
`contracts/`).

---

## Gate Policy

The centrally-defined, versioned set of gate rules every repository
implements. Source: `policy/gate-policy.yml` in this repo.

| Field | Type | Notes |
|-------|------|-------|
| `policy_version` | SemVer string | Matches the tag consumers pin (D10); the drift signal. |
| `categories[]` | list | Required gate categories. |
| `categories[].name` | enum | `tests` \| `quality` \| `security` \| `docs`. |
| `categories[].required` | bool | All true by default (FR-001/002). |
| `categories[].threshold` | object | Category-specific pass condition (e.g., security `min_severity_block: high`). |
| `exemptions[]` | list | Documented exemption labels (e.g., `maintenance`) for spec-trace (D9) and their scope. |
| `bypass.allowed` | bool | True, but only attributable/logged (D13). |
| `bypass.requires` | enum | `admin-override` \| `exemption-label`; never silent (FR-006). |

**Validation rules**:
- At least the four categories MUST be present and `required: true` unless a
  documented exemption exists (FR-002).
- `security.threshold.min_severity_block` MUST be set (default `high`) (FR-004).
- `policy_version` MUST be unique and monotonically increasing per release
  (FR-020).

**Relationships**: Referenced (by pinned version) from every **Repository
Adoption**.

---

## Repository Adoption

How one repository consumes the central policy. Represented by the caller
workflow files in the consuming repo plus its adapter selection. No central
store — the pinned `uses:` ref is the record of truth.

| Field | Type | Notes |
|-------|------|-------|
| `repo` | string | `Odyssey-Classic/<name>` (single org). |
| `pinned_policy_version` | SemVer ref | The `@vX` in `uses:`; equals the policy version this repo implements (FR-018). |
| `adapter` | enum/string | Ecosystem adapter id (`go`, `node`, `docs-only`, …). |
| `license_side` | enum | `agpl-core` \| `apache-edge` — declared per repo (Constitution III). |

**Validation rules**:
- `pinned_policy_version` MUST be an immutable ref (tag/SHA), never a floating
  branch (D10, FR-012 spirit).
- `adapter` MUST resolve to an existing adapter definition or `_template`.
- `license_side` MUST be declared (license-declaration quality check).

**State transitions**: `unadopted → adopted(pinned vX) → upgraded(pinned vY)`.
Drift = the set of repos whose `pinned_policy_version` < latest.

---

## Application Version

The independent, per-application identity carried by a build. Derived, never
hand-assigned (D3, FR-007/008/010).

| Field | Type | Notes |
|-------|------|-------|
| `application` | string | Which application/repo it belongs to. |
| `semver` | SemVer string | `MAJOR.MINOR.PATCH[-prerelease]`. |
| `commit_sha` | string | Exact source (FR-008). |
| `is_prerelease` | bool | True when untagged-commit build or `0.x` / `-rc`. |
| `pre_1_0` | bool | `MAJOR == 0` → triggers compatibility disclaimer (FR-011). |
| `derivation` | enum | `exact-tag` \| `git-describe`. |

**Validation rules**:
- MUST be derivable from git alone (`git describe`); no manual entry (FR-010).
- MUST embed into the artifact and be reportable by the running app
  (US2 scenario 2, SC-002).
- If `pre_1_0`, release notes & version output MUST carry the
  "no compatibility promises" notice (FR-011).

**Relationships**: One **Application Release** references exactly one
Application Version.

---

## Application Release

A named, versioned, published artifact set for one application (D5).

| Field | Type | Notes |
|-------|------|-------|
| `application` | string | Owning application. |
| `version` | → Application Version | The released version. |
| `artifacts[]` | list | Installable outputs (binaries/images/bundles). |
| `release_notes` | markdown | User-visible changes, upgrade steps, breaking changes (FR-013). |
| `attestation[]` | list | Signature + provenance per artifact (D7, FR-014). |
| `checksums` | map | Per-artifact digest. |
| `status` | enum | `published` \| `deprecated` (D14). |
| `published_atomically` | bool | Invariant: consumers see complete release or none (FR-016). |

**Validation rules**:
- MUST be produced by a single triggered action with no manual assembly
  (SC-004).
- MUST be reproducible from the tagged source (FR-012).
- MUST NOT be visible until all assets + notes + attestations are attached
  (FR-016); partial runs fail closed.
- Deprecation marks, never deletes, a defective release (D14).

**State transitions**: `(tag pushed) → building → published → [deprecated]`.
A failed build never reaches `published`.

---

## Spec Reference

The link from a PR to the central spec/version that authorized it (D9, FR-017).

| Field | Type | Notes |
|-------|------|-------|
| `pr` | string | `owner/repo#number`. |
| `spec_id` | string | e.g., `001-cicd-pipeline`. |
| `spec_version` | string | Ratified spec version implemented. |
| `exemption` | enum/null | Documented exemption label if no spec applies. |

**Validation rules**:
- A PR MUST carry either a valid `(spec_id, spec_version)` or a documented
  `exemption`; otherwise the spec-trace gate surfaces the omission to
  reviewers (FR-017) — surfaced, not silently passed.

**Relationships**: Many Spec References → one central spec (this repo's
`specs/<id>`).

---

## Cross-entity invariants

- **Single source of policy**: every Repository Adoption resolves to exactly
  one Gate Policy version; there is no per-repo policy fork (FR-003).
- **Count-agnostic**: nothing above assumes a fixed number of repositories,
  applications, or adapters ([[never-assume-repo-count]]). All repos live under
  the single Odyssey organization.
- **No interop modeling**: there is intentionally no entity relating one
  application's version to another's — interoperability is out of scope.
