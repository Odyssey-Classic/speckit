---
description: "Task list for CI/CD Pipeline, Versioning & Release Process"
---

# Tasks: CI/CD Pipeline, Versioning & Release Process

**Input**: Design documents from `/specs/001-cicd-pipeline/`

**Prerequisites**: plan.md (required), spec.md (user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Per Constitution Principle V (Tested to Be Trusted), behavior is not done until tests prove it. Test tasks are REQUIRED for every user story; the spec's acceptance scenarios MUST be demonstrated by automated tests. Per the plan, tooling is verified by shell-level unit tests (`bats`) plus end-to-end "harness repo" jobs exercising caller workflows against pass/fail fixtures.

**Deliverable note**: This is CI/CD infrastructure, not application code. "Source" is reusable workflows, composite actions, policy config, language adapters, and docs hosted **centrally in this repo** (`Odyssey-Classic/speckit`) and consumed cross-repo. Paths follow `plan.md` → Project Structure.

## Format: `[ID] [P?] [Repo?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Repo]**: Repository the task lands in. This feature defaults to `speckit` (see Deliverable note); only tasks that land elsewhere are tagged (e.g. `[server]`).
- **[Story]**: Which user story this task belongs to (US1–US4)
- Exact file paths are included in each description

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repository scaffolding and the test/lint toolchain everything else builds on.

- [X] T001 Create the central directory structure per plan.md (`.github/workflows/`, `.github/actions/`, `policy/`, `adapters/`, `docs/cicd/`, `tests/fixtures/`, `tests/e2e/`) with `.gitkeep` placeholders
- [X] T002 [P] Add workflow/shell linting config — `actionlint` + `shellcheck` configuration and a root `Makefile` (or `tests/run.sh`) test/lint entrypoint
- [X] T003 [P] Initialize the `bats` shell-test harness under `tests/` (vendor/submodule bats-core; create `tests/unit/` layout)
- [X] T004 [P] Seed `policy/VERSION` with the initial policy version (`1.0.0`) matching the consumer pin scheme (FR-018)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The central gate policy, the adapter contract, and the secure-by-default workflow baseline. These are shared by every user story.

**⚠️ CRITICAL**: No user-story work can begin until this phase is complete.

- [X] T005 Author `policy/gate-policy.yml` per `contracts/gate-policy.schema.md` — the four required categories (`tests`/`quality`/`security`/`docs`), their thresholds (incl. `security.min_severity_block: high`), exemption labels, and bypass rules (FR-002, FR-003, FR-004, FR-006)
- [X] T006 [P] bats validation test `tests/unit/test_gate_policy.bats` — asserts all four categories present + required, `security.min_severity_block` set, every exemption has a description, `bypass.requires != none` with `must_record: [actor, reason]` (FR-002, FR-004, FR-006)
- [X] T007 Create the uniform adapter contract `adapters/_template/adapter.yml` — declared command hooks (`test`, `lint`, `security`, `docs`, `build`, `version-embed`) that any ecosystem fills in as configuration, never bespoke gate logic (FR-003, SC-005)
- [X] T008 [P] Author `adapters/go/adapter.yml` — `go test`, lint/format, `govulncheck`, docs check, reproducible build, and `ldflags` version embedding (FR-003)
- [X] T009 [P] Author `adapters/node/adapter.yml` — Node/web-client equivalents for each command hook (FR-003)
- [X] T010 [P] Author `adapters/docs-only/adapter.yml` — the `speckit` governance profile: document validity + constitution-compliance checks, no code tests (spec Edge Cases & Assumptions: the spec repo is governed, not exempt)
- [X] T011 Establish the secure-by-default workflow baseline (least-privilege `permissions:` defaults, secret masking, no secrets exposed to untrusted fork-PR contexts, auditable secret/signing-key access) as a documented convention + reusable snippet under `.github/actions/` (FR-020, SC-008, Constitution VIII) — every workflow authored later inherits this

**Checkpoint**: Central policy, adapters, and the secure baseline exist — user stories can begin.

---

## Phase 3: User Story 1 - Protected Main Branches (Priority: P1) 🎯 MVP

**Goal**: Every repo blocks merges to `main` until the same categories of gate (tests, quality, security, docs) pass — language-agnostic, configuration-only adoption.

**Independent Test**: Open PRs with (a) a failing test, (b) a known-vulnerable dependency, (c) a pre-existing-only vuln, (d) a clean change — first two blocked with clear reasons, (c) surfaced not blocked, (d) mergeable after review; same categories in a Go and a non-Go repo.

### Tests for User Story 1 (REQUIRED) ⚠️

> Write these FIRST and ensure they FAIL before implementation.

- [ ] T012 [P] [US1] Create gate fixtures under `tests/fixtures/` — `failing-test/`, `known-vuln-dep/`, `preexisting-vuln-only/`, `clean-change/` (US1.1, US1.2, Edge Cases)
- [X] T013 [P] [US1] bats unit test `tests/unit/test_run_gate.bats` — `run-gate` normalizes an adapter command's exit/output into a definitive pass/fail check result (FR-005, SC-003)
- [X] T014 [P] [US1] bats unit test `tests/unit/test_security_baseline.bats` — newly-introduced ≥high vuln blocks; pre-existing vuln is surfaced not blocked (FR-004, research D12)
- [ ] T015 [US1] e2e harness job `tests/e2e/gate-e2e.yml` — runs `gate.yml` against the four fixtures, repeats across a Go and a non-Go adapter (US1.4), and exercises an outside-collaborator/fork PR getting identical gating (US1.5)

### Implementation for User Story 1

- [X] T016 [US1] Author `.github/workflows/gate.yml` reusable workflow — inputs `adapter` + `license_side`, runs every required category from `gate-policy.yml`, rejects `policy_overrides` loudly, emits one check per category (FR-001, FR-003, FR-021, SC-003, SC-005; inherits T011 baseline)
- [X] T017 [US1] Implement the `run-gate` composite `.github/actions/run-gate/action.yml` — invoke a named adapter command and normalize its result (FR-005)
- [X] T018 [US1] Security category baseline diff in `run-gate`/`adapters` — introduced ≥high blocks, pre-existing surfaced (FR-004, research D12)
- [X] T019 [P] [US1] Quality category license-side declaration check (`agpl-core` | `apache-edge`) (FR-021, Constitution III)
- [X] T020 [P] [US1] Docs category — require docs for user-facing changes (FR-002, Constitution VI)
- [X] T021 [US1] Gate-failure messaging — each category reports which gate failed, on what, and what passing requires, without insider interpretation (FR-005)
- [ ] T022 [US1] Bypass recording — any required-gate bypass is attributable, logged, and justified; silent bypass impossible (FR-006, SC-001)
- [ ] T023 [US1] `speckit` self-adoption caller `.github/workflows/ci.yml` using the `docs-only` adapter — dogfoods the gate so the spec repo is not exempt (Edge Cases)
- [ ] T024 [US1] Author `docs/cicd/onboarding.md` — adopt the standard gates + branch protection in a new repo (FR-019, SC-005, Constitution VI)

**Checkpoint**: A repo can adopt the full gate set by configuration alone, and bad PRs are blocked with clear reasons. **MVP deliverable.**

---

## Phase 4: User Story 2 - Coherent Version Identity (Priority: P2)

**Goal**: Every artifact carries a unique, git-derived, reproducible version; the running app reports it; 1.0+ breaks are visible by version alone and pre-1.0 carries a no-promises disclaimer.

**Independent Test**: Build an untagged commit (→ `X.Y.Z-N-g<sha>`), tag and rebuild (→ exact `X.Y.Z` with pre-1.0 disclaimer when `0.x`), and ask the running app its version — all consistent and source-traceable.

### Tests for User Story 2 (REQUIRED) ⚠️

- [ ] T025 [P] [US2] bats tests `tests/unit/test_version_derivation.bats` — every row of `contracts/version-derivation.md` (exact-tag, git-describe, no-tags, dirty→fail) (FR-008, FR-010)
- [ ] T026 [P] [US2] bats test `tests/unit/test_pre_1_0.bats` — `MAJOR == 0` attaches the compatibility disclaimer to version output + notes (FR-011, R3)
- [ ] T027 [US2] e2e `tests/e2e/version-e2e.yml` — untagged build is prerelease, tagged build is exact, and the built app reports the same version its artifact carries (Scenario D, SC-002)

### Implementation for User Story 2

- [ ] T028 [US2] Implement the `derive-version` composite `.github/actions/derive-version/action.yml` — `git describe` algorithm, no human input, dirty build fails (FR-008, FR-009, FR-010, R1)
- [ ] T029 [P] [US2] Artifact version + `commit_sha` embedding and a mandatory version report in `adapters/go` and `adapters/node` (R2, SC-002)
- [ ] T030 [US2] pre-1.0 compatibility disclaimer wired into version output and release notes (FR-011, R3)
- [ ] T031 [P] [US2] Author `policy/versioning-policy.md` — project-wide SemVer rules + the pre-1.0 disclosure requirement (FR-008, FR-011, Constitution VI)

**Checkpoint**: Builds in any repo produce traceable, deterministic versions consumable by releases.

---

## Phase 5: User Story 3 - Cutting a Release (Priority: P3)

**Goal**: One triggered action turns tagged, gated source into a published, signed, verifiable release with generated notes — atomically, with a hotfix path.

**Independent Test**: Push a tag → a single action produces installable artifact(s), notes (changes/upgrade/breaking), checksums, and attestation as one atomic Release; an operator verifies authenticity; a partial failure yields no visible release; a hotfix releases from a tag without unreleased `main` work.

### Tests for User Story 3 (REQUIRED) ⚠️

- [ ] T032 [P] [US3] bats tests `tests/unit/test_release_notes.bats` — notes compose `changes`/`upgrade_steps`/`breaking_changes` from merged-PR metadata; required sections always present (FR-013, research D8)
- [ ] T033 [P] [US3] bats test `tests/unit/test_atomic_publish.bats` — a run failing partway leaves no visible release (FR-016, R1)
- [ ] T034 [US3] e2e `tests/e2e/release-e2e.yml` — cut a release end-to-end (artifacts/notes/checksums/attestation), verify it as an operator, and hotfix from a tag (Scenarios E/F/G, SC-004)

### Implementation for User Story 3

- [ ] T035 [US3] Author `.github/workflows/release.yml` reusable workflow — ordered, fail-closed `derive → build → notes → sign → atomic publish` (FR-012, FR-016, SC-004; inherits T011 baseline)
- [ ] T036 [P] [US3] Implement the `compose-release-notes` composite `.github/actions/compose-release-notes/action.yml` (FR-013, research D8)
- [ ] T037 [P] [US3] Implement the `attest-and-verify` composite `.github/actions/attest-and-verify/action.yml` — signature, provenance, per-artifact checksums (FR-014, research D7)
- [ ] T038 [US3] Atomic publish — release becomes visible only after all assets + notes + attestations are attached; partial runs fail closed (FR-016)
- [ ] T039 [US3] Hotfix path — produce a fixed release from a published tag without including unreleased `main` work (FR-015, Scenario G)
- [ ] T040 [US3] Release deprecation — `status: published → deprecated` with a reason, never delete (research D14/R4; resolves the deferred retraction question)
- [ ] T041 [P] [US3] Author `docs/cicd/release-runbook.md` — cut and hotfix a release (SC-004, Constitution VI)
- [ ] T042 [P] [US3] Author `docs/cicd/verification.md` — how operators verify artifact authenticity (FR-014, SC-006)

**Checkpoint**: An application can be released end-to-end and verified by a fresh operator.

---

## Phase 6: User Story 4 - Cross-Repository Coordination & Spec Traceability (Priority: P4)

**Goal**: Every spec-driven PR is traceable to the central spec that authorized it (feature folder + ratified `speckit` commit/tag); omissions are surfaced, not silently passed; policy-version drift across repos stays visible.

**Independent Test**: PRs with a valid `Spec:` reference pass; one with neither reference nor exemption is surfaced to reviewers; a `maintenance`-labeled PR passes via documented exemption.

### Tests for User Story 4 (REQUIRED) ⚠️

- [ ] T043 [P] [US4] bats tests `tests/unit/test_spec_trace.bats` — every row of `contracts/spec-reference.md` (valid → pass, missing → surfaced, exemption → pass, version-not-found → surfaced) (FR-017, SC-007)
- [ ] T044 [US4] e2e `tests/e2e/spec-trace-e2e.yml` — PRs with reference / no reference / `maintenance` label (Scenario H, SC-007)

### Implementation for User Story 4

- [ ] T045 [US4] Author `.github/workflows/spec-trace.yml` reusable workflow — parse the `Spec: <id>@<ref>` trailer or PR-body field and surface omissions to reviewers unless exempt (FR-017; inherits T011 baseline)
- [ ] T046 [P] [US4] Add `.github/pull_request_template.md` with the Spec ID/reference section and exemption guidance (contracts/spec-reference.md)
- [ ] T047 [US4] Validate `spec_id` against this repo's `specs/` directory and the ratified `speckit` commit/tag; mismatches surfaced to keep drift visible (FR-017, US4.3)
- [ ] T048 [US4] Policy-version drift audit — each repo records its pinned policy version; tooling lists repos behind the latest (FR-018, Scenario I)

**Checkpoint**: All four user stories are independently functional.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Whole-pipeline security verification, proving-ground rollout, and end-to-end validation.

- [ ] T049 [P] SC-008 pipeline-security audit across `gate.yml`, `release.yml`, `spec-trace.yml` and all composites — least-privilege `permissions:` verified, zero plaintext secret/signing-material exposure in logs/artifacts/fork-PR contexts, secret + signing-key access attributable (FR-020, SC-008, Constitution VIII)
- [ ] T050 [P] [server] Proving-ground rollout — add `server` go-profile caller workflows (`ci.yml` + `release.yml` with `adapter: go`) and branch protection (quickstart "Done when")
- [ ] T051 [P] Cross-link the `docs/cicd/` set (index + references between onboarding/runbook/verification/versioning-policy); no code in READMEs, link to the referenced files (Constitution VI)
- [ ] T052 Run `quickstart.md` Scenarios A–I against the proving-ground repos (`speckit` docs-only + `server` go) and record results (quickstart "Done when")
- [ ] T053 [P] Adapter-authoring guide linked from `adapters/_template/` for onboarding a new ecosystem as configuration (FR-003; supports the deferred per-repo adapters)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup — **BLOCKS all user stories**.
- **User Stories (Phase 3–6)**: All depend on Foundational. Once it is done they can proceed in priority order (P1 → P2 → P3 → P4) or in parallel if staffed.
- **Polish (Phase 7)**: Depends on the user stories it audits/validates (T049 after all workflows exist; T052 after all stories).

### User Story Dependencies

- **US1 (P1)**: Needs Foundational only. No dependency on other stories. ← MVP.
- **US2 (P2)**: Needs Foundational only. Independent of US1 (shares adapters but is separately testable).
- **US3 (P3)**: Functionally builds on US2's version derivation (T028 used by T035), but its tasks are independently testable; if run alone, T035 stubs version input.
- **US4 (P4)**: Needs Foundational only. Fully independent of US1–US3.

### Within Each Story

- Tests are written and FAIL before implementation.
- Adapter/policy config before the composites that consume it; composites before the reusable workflow that orchestrates them; core behavior before docs.

### Critical cross-cutting

- **T011 (secure-by-default baseline)** is foundational and is inherited by every workflow authored later (T016, T035, T045); T049 verifies it holds.

---

## Parallel Opportunities

- **Setup**: T002, T003, T004 in parallel after T001.
- **Foundational**: T006 + the adapters T008/T009/T010 in parallel after their bases (T005/T007); T011 in parallel with the adapters.
- **Across stories**: once Phase 2 is done, US1/US2/US4 can be developed fully in parallel by different people; US3 trails US2 slightly for version derivation.
- **Within a story**: all `[P]` test tasks together first; then `[P]` implementation tasks (different files) together.

### Parallel Example: User Story 1

```bash
# Tests first (different files):
Task: "Gate fixtures in tests/fixtures/ (T012)"
Task: "bats run-gate test in tests/unit/test_run_gate.bats (T013)"
Task: "bats security-baseline test in tests/unit/test_security_baseline.bats (T014)"

# Then parallel implementation (different files):
Task: "Quality license-side check (T019)"
Task: "Docs-required check (T020)"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 Setup → 2. Phase 2 Foundational (CRITICAL) → 3. Phase 3 US1 → 4. **STOP & VALIDATE** gate behavior against the four fixtures and across two adapters → 5. Roll out gates to the proving-ground repos.

### Incremental Delivery

Foundation → US1 (gates, MVP) → US2 (versions) → US3 (releases) → US4 (traceability) → Polish. Each story adds value and stays independently testable.

---

## Notes

- `[P]` = different files, no incomplete dependencies.
- `[Repo]` tags a task landing outside the default repo (`speckit`) — here, only T050 (`server`).
- `[Story]` labels map tasks to spec user stories for traceability.
- Verify tests fail before implementing (Constitution V).
- This repo is its own first consumer (docs-only profile) — dogfood the gates (T023).
- Total: 53 tasks (Setup 4, Foundational 7, US1 13, US2 7, US3 11, US4 6, Polish 5).
