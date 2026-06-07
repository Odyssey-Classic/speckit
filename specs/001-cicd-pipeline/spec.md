# Feature Specification: CI/CD Pipeline, Versioning & Release Process

**Feature Branch**: `001-cicd-pipeline`

**Created**: 2026-06-05

**Status**: Draft

**Input**: User description: "Our first spec is going to be our approach to CI/CD. We need coherent versioning across disparate languages and environments. We want to perform security checks, quality checks, and other proper gating on PRs being merged into main. We'll also need to determine how we release software. Please consider the issues we may have working with SpecKit, and in general, working across multiple repositories for a single application."

## Overview

Odyssey is a single application — an online RPG engine — built across multiple
repositories in different languages and runtime environments. This spec
defines how the project protects its main branches, keeps version identity
coherent across those repositories, and turns merged work into releases that
hobbyist operators can confidently install and upgrade. It also defines how
the multi-repository, spec-first workflow (Constitution Principle IV) is kept
honest: work landing in any repository remains traceable to the central spec
that authorized it.

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
   (tests, quality, security) are enforced in both.
5. **Given** a contribution from an outside collaborator without project
   privileges, **When** their pull request is opened, **Then** it receives
   the same gating as a maintainer's pull request before it can merge.

---

### User Story 2 - Coherent Version Identity (Priority: P2)

Every component of Odyssey carries its own independent version, and the game
server is the anchor of compatibility: each server release authoritatively
declares which client version(s) it accepts. Declared client versions remain
published and retrievable, so the right client can always be obtained for a
given server. An operator, contributor, or maintainer can ask any built or
running component what version it is, and can determine from a server release
exactly which client versions belong with it — even though the components are
built in different repositories, languages, and environments.

**Why this priority**: Without coherent version identity, multi-repository
problems become undiagnosable ("which server build is incompatible with which
client build?") and releases (Story 3) have no stable thing to point at. It
builds directly on Story 1's trustworthy main branches.

**Independent Test**: Can be tested by building components from two or more
repositories, then verifying that (a) each built artifact carries a unique,
traceable version, (b) a server release declares the exact client version(s)
it accepts, (c) every declared client version is retrievable, and (d)
compatibility between a server and a client is determinable from the server's
declaration alone, without inspecting code.

**Acceptance Scenarios**:

1. **Given** any built artifact from any repository, **When** its version is
   inspected, **Then** it uniquely identifies the exact source it was built
   from.
2. **Given** a server release, **When** anyone inspects it, **Then** it
   declares the exact client version(s) it accepts.
3. **Given** a server release's declared client versions, **When** any one of
   them is requested, **Then** that client version is retrievable for as long
   as a supported server release declares it.
4. **Given** a server and a client, **When** their compatibility is in
   question, **Then** it is determinable from the server's declaration alone
   — without reading code or asking the project.
5. **Given** a change merges to main in any repository, **When** the next
   build occurs, **Then** its version is assigned deterministically — no
   human invents version numbers ad hoc.

---

### User Story 3 - Cutting a Release (Priority: P3)

A release manager decides a component is ready to release. They initiate a
release of that component, and the outcome is a named, versioned, installable
artifact with release notes describing what changed and a way for operators
to verify it is authentic and untampered. Components release independently;
the server release is the operator-facing anchor — when a server release is
cut, its declared client version(s) must already be published, so an operator
who installs or upgrades a server always has a working, compatible client
available. An operator running an Odyssey world can discover a new server
release, read what changed, and upgrade.

**Why this priority**: Releases are the project's product reaching its
users (operators and their players), but they require Stories 1 and 2 to be
meaningful. The constitution's "small communities" identity requires hosting
to stay practical for hobbyists — releases are where that promise is kept or
broken.

**Independent Test**: Can be tested by cutting a release end-to-end:
verifying it produces versioned artifacts for every component, generated
release notes, integrity verification material, and that a fresh operator
can go from "nothing installed" to "running the released version" using only
the release and its documentation.

**Acceptance Scenarios**:

1. **Given** a component's main branch in a releasable state, **When** the
   release manager cuts a release of that component, **Then** a versioned,
   installable artifact for it is published, consistent with the versioning
   rules from Story 2.
2. **Given** a server release being cut, **When** any client version it
   declares is not yet published and retrievable, **Then** publication is
   blocked before operators can see the release.
3. **Given** a published release, **When** an operator reads it, **Then**
   release notes describe user-visible changes, upgrade steps, and any
   breaking changes since the prior release of that component.
4. **Given** a downloaded release artifact, **When** an operator checks it,
   **Then** they can verify it is authentic and has not been tampered with.
5. **Given** a critical defect found in the latest release of a component,
   **When** a fix is prepared, **Then** a corrected release can be produced
   without shipping unrelated unfinished work from main.

---

### User Story 4 - Cross-Repository Coordination & Spec Traceability (Priority: P4)

A maintainer reviewing work anywhere in the project can trace it to the
central spec that authorized it (Constitution Principle IV). When a single
feature requires coordinated changes in multiple repositories — for example,
a change to how server and client talk to each other — the process makes the
coordination visible: each repository's work references the same spec, and a
release cannot silently combine halves of a cross-repository change that
don't work together.

**Why this priority**: This is the "working with SpecKit across multiple
repositories" glue. It matters most as the number of repositories and
contributors grows; with one founder and two repositories it is cheap to do
informally, which is why it is prioritized after the foundational gates,
versioning, and releases.

**Independent Test**: Can be tested by simulating a cross-repository feature:
verifying each repository's pull requests reference the central spec,
verifying a pull request with no spec reference (and no documented exemption)
is flagged, and verifying that a release attempted with only one half of a
coordinated change is detected as incompatible before publication.

**Acceptance Scenarios**:

1. **Given** a pull request implementing spec-driven work in any repository,
   **When** it is reviewed, **Then** it identifies the central spec (and its
   version) that it implements.
2. **Given** a pull request with no spec reference and no documented
   exemption (e.g., routine maintenance), **When** gates run, **Then** the
   omission is surfaced to the reviewer rather than passing silently.
3. **Given** a coordinated cross-repository change where only one
   repository's half has merged, **When** a release is attempted, **Then**
   the incompatibility is detected before the release is published.
4. **Given** a ratified spec changes version, **When** downstream
   repositories next take up work on it, **Then** each repository's tracked
   spec version is updated, keeping drift visible.

---

### Edge Cases

- **Pre-existing vulnerabilities**: A security scan flags a vulnerability in
  an existing dependency that the pull request did not touch. The gate must
  distinguish "you introduced this" (block) from "this already exists"
  (surface and track, do not punish the unrelated contributor).
- **Cross-repository breaking change**: Server and client must change
  together, but merges happen one repository at a time. Between the two
  merges, main branches are individually green but mutually incompatible.
  The server's compatibility declaration closes this window for operators —
  a server release that needs the new client declares only client versions
  that actually exist and work with it, and cannot be published before they
  do (Story 3, scenario 2).
- **Hotfixing a release**: A severe bug is found in the latest release while
  main has accumulated unreleased work. The process must support releasing a
  fix without dragging unreleased changes along (Story 3, scenario 5).
- **A declared client version goes bad**: A client version declared by
  published server releases is later found to have a serious defect or
  vulnerability. The process must support publishing a corrected client and
  updating affected servers' declarations, without breaking operators running
  in the meantime.
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
- **Partial release failure**: A component release fails partway through
  publication. Consumers must never observe the half-published state as a
  usable release — they see either the complete new release or the prior one.

## Requirements *(mandatory)*

### Functional Requirements

**Merge gating (every repository)**

- **FR-001**: Every Odyssey repository MUST block merging into main until all
  required gates pass and at least the review required by the constitution's
  Development Workflow is complete.
- **FR-002**: Required gates MUST cover, at minimum: automated tests, code
  quality standards, and security checks (both the contributed changes and
  the dependencies they bring in).
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

**Versioning (coherence across repositories)**

- **FR-007**: The project MUST define a single versioning policy, recorded in
  this repository, under which every component carries its own independent
  version.
- **FR-008**: Every built artifact MUST carry a version that uniquely and
  reproducibly identifies the exact source it was built from.
- **FR-009**: Every server release MUST declare the exact client version(s)
  it accepts; that declaration is the authoritative compatibility record
  between server and client.
- **FR-010**: Version assignment on merge and release MUST be deterministic
  and automatic; no step may depend on a person inventing a number.
- **FR-011**: The versioning policy MUST make breaking changes visible in
  each component's version identity, so operators can distinguish safe
  upgrades from ones requiring attention.
- **FR-012**: Every client version declared by a supported server release
  MUST remain published and retrievable for as long as any supported server
  release declares it.

**Releases**

- **FR-013**: A release MUST be producible from tagged, gated source alone —
  rebuilding the same release version yields functionally identical
  artifacts.
- **FR-014**: Every release MUST include release notes covering user-visible
  changes, upgrade steps, and breaking changes since the previous release of
  that component.
- **FR-015**: Operators MUST be able to verify the authenticity and integrity
  of every published release artifact.
- **FR-016**: The process MUST support producing a fixed release of a
  component from its latest published release without including unreleased
  work from main.
- **FR-017**: A component release MUST be published atomically from the
  consumer's view — operators either see the complete release or the prior
  one, never a partial publication.
- **FR-018**: A server release MUST NOT be publishable unless every client
  version it declares is already published and retrievable — a half-merged
  cross-repository change cannot reach operators.

**Cross-repository & SpecKit coordination**

- **FR-019**: Pull requests implementing spec-driven work MUST reference the
  central spec and spec version they implement; pull requests without a
  reference MUST be surfaced to reviewers unless covered by a documented
  exemption category (e.g., routine maintenance).
- **FR-020**: The gating, versioning, and release policies themselves MUST be
  versioned in this repository, and each repository MUST record which policy
  version it currently implements, keeping drift detectable.
- **FR-021**: Adopting the standard gates in a new Odyssey repository MUST be
  a documented, repeatable procedure rather than a bespoke design effort.

### Key Entities

- **Gate Policy**: The centrally defined set of gate categories, blocking
  thresholds, and exemption rules that every repository implements; itself
  versioned.
- **Component Version**: The independent identity carried by each component's
  built artifact, uniquely tied to its exact source; governed by the
  project-wide versioning policy.
- **Component Release**: A named, versioned, published artifact for one
  component, with release notes and verification material. The server release
  is the operator-facing anchor: the unit operators install and upgrade.
- **Compatibility Declaration**: The authoritative record, carried by each
  server release, of the exact client version(s) that server accepts.
- **Spec Reference**: The link from a unit of work (pull request) in any
  repository to the central spec and spec version that authorized it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of merges into main across all Odyssey repositories pass
  the required gates or carry a recorded, attributed, written justification —
  zero silent bypasses.
- **SC-002**: For any published server release, anyone can determine the
  exact client version(s) it accepts from the release itself in under one
  minute.
- **SC-003**: A contributor receives complete pass/fail gate feedback on a
  pull request within 15 minutes of opening or updating it.
- **SC-004**: A release — artifacts, notes, verification material — can be
  cut by one person in under one hour of hands-on effort.
- **SC-005**: A brand-new repository can adopt the full standard gate set
  within one working day using only the documented procedure.
- **SC-006**: No server release is ever published declaring a client version
  that is not itself published and retrievable (zero occurrences).
- **SC-007**: A fresh operator can go from nothing installed to running the
  latest release, using only the release and its notes, without contacting
  the project for help.
- **SC-008**: 100% of spec-driven pull requests are traceable to a central
  spec version; untraceable pull requests outside exemption categories are
  flagged before merge.

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
- The Odyssey application currently spans this spec repository and the server
  repository, with at least a client repository expected; the policies must
  hold for N repositories, not just the current set.
- The server is the operator-facing unit of installation; players reach the
  client through a world's server (web-first play), so keeping every declared
  client version published and retrievable is a project obligation, not an
  operator burden.
- "Supported" follows the latest-release-line assumption above: client
  retrievability is guaranteed for client versions declared by the latest
  server release line; declarations by retired server releases may lapse.
- This spec repository is itself a governed repository: its gates validate
  documents and constitutional compliance rather than running code tests.
- Released artifacts are what operators run to host worlds; per the
  constitution's Engine Identity, install and upgrade must remain practical
  for a hobbyist (no specialist infrastructure assumed).
- Operator-side deployment automation (tooling that manages a running world's
  infrastructure) is out of scope for this spec; it covers the project's
  pipeline from contribution to published release.
- Distribution channels and marketing of releases (websites, registries,
  announcements) are out of scope beyond the release being published,
  verifiable, and documented.
