# Feature Specification: CI/CD Pipeline, Versioning & Release Process

**Feature Branch**: `001-cicd-pipeline`

**Created**: 2026-06-05

**Status**: Draft

**Input**: User description: "Our first spec is going to be our approach to CI/CD. We need coherent versioning across disparate languages and environments. We want to perform security checks, quality checks, and other proper gating on PRs being merged into main. We'll also need to determine how we release software. Please consider the issues we may have working with SpecKit, and in general, working across multiple repositories for a single application."

## Overview

Odyssey — an online RPG engine — is delivered as a set of cooperating
applications: game servers, clients, admin tools, a world registry, and
others as features require, built across multiple repositories in different
languages and runtime environments. This spec defines how the project
protects its main branches, keeps version identity coherent across those
repositories and applications, and turns merged work into releases that
hobbyist operators can confidently install and upgrade. It also defines how
the multi-repository, spec-first workflow (Constitution Principle IV) is kept
honest: work landing in any repository remains traceable to the central spec
that authorized it. How those applications interoperate — which versions
work together at runtime — is deliberately out of scope here and will be
specified separately.

## Clarifications

### Session 2026-06-06

- Q: Is Odyssey a single application? → A: No — a set of cooperating
  applications (servers, clients, admin tools, world registry, others as
  features require); this spec's canonical term for one such application is
  "application" (formerly "component").
- Q: How is versioning/compatibility governed across applications beyond
  server→client? → A: No global topology is mandated — each application has
  different requirements and is responsible for creating, managing, and
  reporting its own version, with semantic versioning (SemVer) as the
  project-wide standard for version-part meanings. Interoperability — which
  versions of which applications work together, including the earlier
  server→client acceptance model — is out of scope for this spec and
  deferred to a dedicated spec.
- Q: Does releasing include operating anything (e.g., a project-hosted world
  registry service)? → A: No — every application, registry included, is
  released as installable software; anyone who runs an instance, including
  the project itself, does so as an operator, outside this spec.
- Q: What do versions promise before 1.0? → A: Strict SemVer — pre-1.0
  versions promise nothing about compatibility, and every pre-1.0 release
  must make that clearly visible to operators; full breaking-change
  visibility (FR-011) applies from 1.0.0 onward.

### Session 2026-06-07

- Q: How many repositories does the project span? → A: Never assume a count
  (there are already more than the spec guessed); this document and all
  derived documents must stay correct for any number of repositories and
  applications.
- Q: SC-003's 15-minute gate-feedback bound seems arbitrary and breaks once
  integration testing is added — keep it? → A: No — drop the time bound. The
  provable property is that every required gate runs automatically on every
  PR and reports a definitive pass/fail without manual triggering; feedback
  speed is a plan-time tuning target, not a spec promise.
- Q: SC-004 and SC-005 measure human effort/time, which can't be tracked or
  proven — replace them? → A: Yes, reframe both to observable properties.
  SC-004: a release is produced by one triggered action that generates all
  required outputs with no manual assembly. SC-005: a new repository adopts
  the full standard gate set by applying the shared gate configuration,
  authoring zero bespoke gate logic. (Human-time targets are not provable
  acceptance criteria.)

### Session 2026-06-09

- Q: FR-014 implies the pipeline signs releases and holds publishing
  credentials, yet the spec set no requirement for protecting the pipeline's
  own secrets (Constitution Principle VIII). Add one? → A: Yes — add a
  functional requirement that the pipeline handle its own credentials and
  release-signing material with least privilege, never expose secrets in
  plaintext (logs, build artifacts, untrusted fork-PR contexts), and keep
  secret and signing-key access auditable.
- Q: FR-017 requires pull requests to reference "the central spec and spec
  version," but what identifies a spec's version? → A: A spec is identified by
  its feature folder (e.g., `001-cicd-pipeline`) together with the `speckit`
  git commit or tag at which that spec was ratified; pull requests cite that
  pair. No separate per-spec version-number scheme is introduced.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Protected Main Branches (Priority: P1)

A contributor opens a pull request against `main` in any Odyssey repository.
Before the change can merge, automated gates verify it: tests pass, code
quality standards are met, and no known security problems are introduced. The
same *categories* of gate apply in every repository, regardless of the
language or environment that repository uses, so "merged into main" means the
same level of assurance everywhere in the project.

**Why this priority**: The constitution makes quality gates a merge
requirement, not a follow-up (Principle V, Development Workflow). Every other
part of this spec — trustworthy versions, trustworthy releases — depends on
main branches that only contain gated work. This is also valuable entirely on
its own, even if versioning and releases come later.

**Independent Test**: Can be fully tested by opening pull requests in each
repository with (a) a deliberate test failure, (b) a deliberate quality
violation, (c) a known-vulnerable dependency, and (d) a clean change —
verifying the first three are blocked with clear explanations and the fourth
is mergeable after review.

**Acceptance Scenarios**:

1. **Given** a pull request whose changes break a test, **When** the gates
   complete, **Then** merging is blocked and the contributor can see which
   gate failed and why.
2. **Given** a pull request that introduces a dependency with a known
   high-severity vulnerability, **When** the security gate runs, **Then**
   merging is blocked and the finding identifies the offending dependency.
3. **Given** a pull request that passes all gates and has an approving
   review, **When** the contributor merges, **Then** the merge succeeds.
4. **Given** any two Odyssey repositories in different languages, **When**
   pull requests are opened in each, **Then** the same categories of gate
   (tests, quality, security, documentation) are enforced in both.
5. **Given** a contribution from an outside collaborator without project
   privileges, **When** their pull request is opened, **Then** it receives
   the same gating as a maintainer's pull request before it can merge.

---

### User Story 2 - Coherent Version Identity (Priority: P2)

Every Odyssey application creates, manages, and reports its own version, with
semantic versioning giving version parts the same meaning across the whole
project. An operator, contributor, or maintainer can ask any built artifact
or running application what version it is and trace that version to the exact
source it was built from — even though the applications are built in
different repositories, languages, and environments.

**Why this priority**: Without coherent version identity, multi-repository
problems become undiagnosable ("which build of which application is this?")
and releases (Story 3) have no stable thing to point at. It builds directly
on Story 1's trustworthy main branches.

**Independent Test**: Can be tested by building artifacts from two or more
repositories, then verifying that (a) each carries a unique, traceable
version, (b) each application reports its version on demand, and (c) for
applications at 1.0.0 or later, a breaking change is distinguishable from a
non-breaking one by version identity alone.

**Acceptance Scenarios**:

1. **Given** any built artifact from any repository, **When** its version is
   inspected, **Then** it uniquely identifies the exact source it was built
   from.
2. **Given** a running application, **When** it is asked for its version,
   **Then** it reports the same version its artifact carries.
3. **Given** a release of an application at or beyond 1.0.0 that contains a
   breaking change, **When** its version is compared with the prior
   release's, **Then** the version identity alone signals the break, per
   semantic versioning.
4. **Given** a pre-1.0 release, **When** an operator reads its release notes
   or version information, **Then** it clearly states that pre-1.0 versions
   make no compatibility promises.
5. **Given** a change merges to main in any repository, **When** the next
   build occurs, **Then** its version is assigned deterministically under the
   owning application's recorded rules — no human invents version numbers ad
   hoc.

---

### User Story 3 - Cutting a Release (Priority: P3)

A release manager decides an application is ready to release. They initiate
a release, and the outcome is a named, versioned, installable artifact with
release notes describing what changed and a way for operators to verify it
is authentic and untampered. Applications release independently, each on its
own cadence. An operator running an Odyssey world can discover a new release
of an application they run, read what changed, and upgrade.

**Why this priority**: Releases are the project's product reaching its
users (operators and their players), but they require Stories 1 and 2 to be
meaningful. The constitution's "small communities" identity requires hosting
to stay practical for hobbyists — releases are where that promise is kept or
broken.

**Independent Test**: Can be tested by cutting a release of one application
end-to-end: verifying it produces a versioned artifact, generated release
notes, integrity verification material, and that a fresh operator can go
from "nothing installed" to "running the released version" using only the
release and its documentation.

**Acceptance Scenarios**:

1. **Given** an application's main branch in a releasable state, **When** the
   release manager cuts a release of that application, **Then** a versioned,
   installable artifact for it is published, consistent with the versioning
   rules from Story 2.
2. **Given** a published release, **When** an operator reads it, **Then**
   release notes describe user-visible changes, upgrade steps, and any
   breaking changes since the prior release of that application.
3. **Given** a downloaded release artifact, **When** an operator checks it,
   **Then** they can verify it is authentic and has not been tampered with.
4. **Given** a critical defect found in the latest release of an application,
   **When** a fix is prepared, **Then** a corrected release can be produced
   without shipping unrelated unfinished work from main.

---

### User Story 4 - Cross-Repository Coordination & Spec Traceability (Priority: P4)

A maintainer reviewing work anywhere in the project can trace it to the
central spec that authorized it (Constitution Principle IV). When a single
feature requires coordinated changes in multiple repositories — for example,
a change to how server and client talk to each other — the process makes the
coordination visible: each repository's work references the same spec, so
reviewers in every repository can see the whole of the change they are
approving a part of.

**Why this priority**: This is the "working with SpecKit across multiple
repositories" glue. It matters most as the number of repositories and
contributors grows; while the contributor base is small it is cheap to do
informally, which is why it is prioritized after the foundational gates,
versioning, and releases.

**Independent Test**: Can be tested by simulating a cross-repository feature:
verifying each repository's pull requests reference the central spec, and
verifying a pull request with no spec reference (and no documented exemption)
is flagged.

**Acceptance Scenarios**:

1. **Given** a pull request implementing spec-driven work in any repository,
   **When** it is reviewed, **Then** it identifies the central spec (and its
   version) that it implements.
2. **Given** a pull request with no spec reference and no documented
   exemption (e.g., routine maintenance), **When** gates run, **Then** the
   omission is surfaced to the reviewer rather than passing silently.
3. **Given** a ratified spec changes version, **When** downstream
   repositories next take up work on it, **Then** each repository's tracked
   spec version is updated, keeping drift visible.

---

### Edge Cases

- **Pre-existing vulnerabilities**: A security scan flags a vulnerability in
  an existing dependency that the pull request did not touch. The gate must
  distinguish "you introduced this" (block) from "this already exists"
  (surface and track, do not punish the unrelated contributor).
- **Cross-repository breaking change**: Two applications must change
  together, but merges happen one repository at a time, leaving a window
  where main branches are individually green yet mutually incompatible.
  Managing that window is an interoperability concern — explicitly out of
  scope for this spec (see Assumptions) and deferred to a dedicated
  interoperability spec. This spec's contribution is the raw material:
  trustworthy versions (Story 2) and spec traceability (Story 4).
- **Hotfixing a release**: A severe bug is found in the latest release while
  main has accumulated unreleased work. The process must support releasing a
  fix without dragging unreleased changes along (Story 3, scenario 4).
- **The spec repository itself**: This repository contains specs, not
  shipping code. Its "quality gates" are necessarily different in kind
  (document validity, constitution compliance) but it must not be exempt
  from gating into main.
- **A language or environment without mature check tooling**: A repository's
  ecosystem may lack a standard tool for some gate category. The gate
  categories are mandatory; the rigor must be matched in intent, with any gap
  documented as a justified exception rather than silently skipped.
- **Gate outage or false positive**: A required check is unavailable or
  wrongly fails. Overrides must be possible but never silent — every bypass
  is recorded, attributed, and justified.
- **Partial release failure**: An application release fails partway through
  publication. Consumers must never observe the half-published state as a
  usable release — they see either the complete new release or the prior one.

## Requirements *(mandatory)*

### Functional Requirements

**Merge gating (every repository)**

- **FR-001**: Every Odyssey repository MUST block merging into main until all
  required gates pass and at least the review required by the constitution's
  Development Workflow is complete.
- **FR-002**: Required gates MUST cover, at minimum: automated tests, code
  quality standards, security checks (both the contributed changes and the
  dependencies they bring in), and documentation requirements (a merge
  requirement per the constitution, Principle VI).
- **FR-003**: Gate categories and their blocking thresholds MUST be defined
  once, centrally, in this repository — with each repository adapting only
  the language-specific *means* of satisfying them, never the categories or
  thresholds themselves.
- **FR-004**: Security gates MUST block merges that introduce known
  vulnerabilities at or above an agreed severity threshold, and MUST surface
  (without blocking the unrelated change) pre-existing vulnerabilities
  discovered in scans.
- **FR-005**: Every gate failure MUST tell the contributor which gate failed,
  on what, and what passing requires — without needing project insiders to
  interpret it.
- **FR-006**: Any bypass of a required gate MUST be recorded, attributed to a
  named person, and justified in writing; silent bypass MUST NOT be possible.

**Versioning (per-application ownership)**

- **FR-007**: Each application MUST create, manage, and report its own
  version; no other application or central authority assigns versions on its
  behalf.
- **FR-008**: The project-wide versioning standard, recorded in this
  repository, is semantic versioning: version-part meanings (breaking /
  feature / fix) MUST be uniform across all applications.
- **FR-009**: Every built artifact MUST carry a version that uniquely and
  reproducibly identifies the exact source it was built from.
- **FR-010**: Version assignment on merge and release MUST be deterministic
  and automatic under the owning application's recorded rules; no step may
  depend on a person inventing a number.
- **FR-011**: From version 1.0.0 of an application onward, breaking changes
  MUST be visible in its version identity per semantic versioning, so
  consumers can distinguish safe upgrades from ones requiring attention.
  Before 1.0.0, per strict semantic versioning, versions promise nothing
  about compatibility — and every pre-1.0 release MUST make that clearly
  visible to operators in its release notes and version presentation.

**Releases**

- **FR-012**: A release MUST be producible from tagged, gated source alone —
  rebuilding the same release version yields functionally identical
  artifacts.
- **FR-013**: Every release MUST include release notes covering user-visible
  changes, upgrade steps, and breaking changes since the previous release of
  that application.
- **FR-014**: Operators MUST be able to verify the authenticity and integrity
  of every published release artifact.
- **FR-015**: The process MUST support producing a fixed release of an
  application from its latest published release without including unreleased
  work from main.
- **FR-016**: An application release MUST be published atomically from the
  consumer's view — operators either see the complete release or the prior
  one, never a partial publication.

**Cross-repository & SpecKit coordination**

- **FR-017**: Pull requests implementing spec-driven work MUST reference the
  central spec they implement — identified by its feature folder (e.g.,
  `001-cicd-pipeline`) together with the `speckit` git commit or tag at which
  that spec was ratified — so the exact authorizing spec revision is
  traceable. No separate per-spec version-number scheme is introduced. Pull
  requests without such a reference MUST be surfaced to reviewers unless
  covered by a documented exemption category (e.g., routine maintenance).
- **FR-018**: The gating, versioning, and release policies themselves MUST be
  versioned in this repository, and each repository MUST record which policy
  version it currently implements, keeping drift detectable.
- **FR-019**: Adopting the standard gates in a new Odyssey repository MUST be
  a documented, repeatable procedure rather than a bespoke design effort.

**Pipeline security (secure by default)**

- **FR-020**: The pipeline MUST protect its own credentials and
  release-signing material (Constitution Principle VIII): every stage uses
  least-privilege credentials scoped to what it needs; secrets MUST NOT be
  exposed in plaintext, including in logs, build artifacts, or untrusted
  fork-pull-request contexts; and access to secrets and signing keys MUST be
  attributable and auditable. This governs the pipeline's own posture and is
  distinct from the security *gates* on contributed code (FR-004).

### Key Entities

- **Gate Policy**: The centrally defined set of gate categories, blocking
  thresholds, and exemption rules that every repository implements; itself
  versioned.
- **Application Version**: The independent identity carried by each
  application's built artifact, created and managed by the owning application
  and uniquely tied to its exact source; semantic versioning gives its parts
  uniform meaning project-wide.
- **Application Release**: A named, versioned, published artifact for one
  application, with release notes and verification material; the unit
  operators install and upgrade.
- **Spec Reference**: The link from a unit of work (pull request) in any
  repository to the central spec that authorized it — the spec's feature
  folder (e.g., `001-cicd-pipeline`) plus the `speckit` git commit or tag at
  which it was ratified. No separate per-spec version number is introduced.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of merges into main across all Odyssey repositories pass
  the required gates or carry a recorded, attributed, written justification —
  zero silent bypasses.
- **SC-002**: 100% of published artifacts and running applications report a
  version traceable to the exact source they were built from — zero
  unversioned or untraceable releases.
- **SC-003**: Every required gate runs automatically on every pull request
  and reports a definitive pass/fail result without any manual triggering
  (100% of pull requests; zero gates requiring a human to start them).
- **SC-004**: A release is produced by a single triggered action that
  generates all required outputs (artifacts, release notes, verification
  material) with no manual assembly of any artifact.
- **SC-005**: A new repository adopts the full standard gate set by applying
  the shared gate configuration, authoring zero bespoke gate logic — adoption
  is configuration, not design.
- **SC-006**: A fresh operator can go from nothing installed to running the
  latest release, using only the release and its notes, without contacting
  the project for help.
- **SC-007**: 100% of spec-driven pull requests are traceable to a central
  spec revision (feature folder + ratified `speckit` commit/tag); untraceable
  pull requests outside exemption categories are flagged before merge.
- **SC-008**: Every pipeline run uses least-privilege credentials and exposes
  zero secrets or signing material in logs, build artifacts, or fork-pull-
  request contexts; 100% of secret and signing-key accesses are attributable —
  zero plaintext secret exposure.

## Assumptions

- The project uses a hosted git platform with pull-request workflows and
  branch-protection capability; "PR into main" is the universal contribution
  path in every repository.
- Main is kept releasable at all times; releases are cut deliberately by a
  release manager (initially the founder) rather than on a fixed calendar
  cadence or automatically on every merge.
- Only the latest release line receives fixes; long-term support for older
  releases is out of scope while the project is young.
- The security gate's default blocking threshold is high-severity and above
  for known vulnerabilities, with lower severities surfaced but not blocking;
  the threshold is part of the central gate policy and adjustable there.
- The Odyssey project spans multiple repositories, and that number changes
  over time as applications are added (servers, clients, admin tools, world
  registry, and others as features require); no policy, document, or
  procedure may assume a fixed count of repositories or applications.
- Interoperability between applications — which versions work together at
  runtime, and how compatibility is declared or enforced (including
  server↔client acceptance) — is explicitly out of scope for this spec and
  will be addressed in a dedicated spec.
- This spec repository is itself a governed repository: its gates validate
  documents and constitutional compliance rather than running code tests.
- Released artifacts are what operators run to host worlds; per the
  constitution's Engine Identity, install and upgrade must remain practical
  for a hobbyist (no specialist infrastructure assumed).
- Every application — including any future service-shaped ones such as the
  world registry — is released as installable software; the project's
  responsibility ends at the published, verifiable artifact. If the project
  runs an instance of any application, it does so as an operator, outside
  this spec.
- Operator-side deployment automation (tooling that manages a running world's
  infrastructure) is out of scope for this spec; it covers the project's
  pipeline from contribution to published release.
- Distribution channels and marketing of releases (websites, registries,
  announcements) are out of scope beyond the release being published,
  verifiable, and documented.
