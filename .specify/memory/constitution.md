<!--
Sync Impact Report
==================
Version change: 0.3.0 → 0.4.0 (MINOR: licensing policy added to Principle III)
Modified principles:
  - III. Open Ecosystem, No Lock-In (commons guarantee made concrete:
    AGPL-3.0 engine core + Apache-2.0 edges; world-content boundary added —
    creators' worlds are not derivative works of the engine)
  - Governance (founder named: Christopher Lowenthal)
Added sections: none
Removed sections: none
Templates requiring updates:
  - ✅ .specify/templates/plan-template.md (Constitution Check gate already
    generic; gates derive from this document — no edit needed)
  - ✅ .specify/templates/spec-template.md (no constitution-specific sections
    required — no edit needed)
  - ✅ .specify/templates/tasks-template.md (security hardening already present
    in Polish phase; Principle V references unchanged — no edit needed)
Follow-up TODOs:
  - TODO(RATIFICATION_DATE): set when the draft is formally ratified as v1.0.0
-->

# Odyssey Constitution

**Status**: DRAFT — this constitution is open for revision and has not yet
been formally ratified. Formal ratification will be marked by v1.0.0.

Odyssey is an open source engine for online RPGs: persistent, shared worlds
played together in small communities. The engine is opinionated — it ships one
complete style of game — so that creators can spend their energy building
unique worlds and content instead of rebuilding systems. This constitution is
the centralized, binding charter for every repository in the Odyssey project.

## Core Principles

### I. Complete Game First

Every creator who adopts Odyssey MUST start from a fully functional game. The
engine's set of functionality, style of client, and player capabilities are
deliberately not widely adaptable; that focus is what guarantees a complete,
playable game on day one. Creators differentiate their worlds through unique
content — not by reassembling core systems.

- The default path MUST always produce a complete, playable game with no
  additional system-building required.
- Engine features MUST be designed as opinionated defaults: a clear default
  shape that works out of the box, which builders MAY override with effort but
  are never required to touch.
- A change that leaves the out-of-the-box game incomplete, or that pushes
  system-assembly work onto creators, violates this principle regardless of
  the flexibility it adds.

**Rationale**: The engine's value is measured by how quickly a creator's
unique world becomes playable, not by how many kinds of games it could
theoretically run.

### II. Players First

When the needs of players, creators, operators, or the project itself
conflict, players win. This commits every repository to four vows, even at
cost to creator convenience or project growth:

- **Fairness**: Engine capabilities MUST NOT enable real money to buy
  in-game power or advantage. Operators MAY charge for access or support of
  their world, but nothing purchasable — through the engine or alongside
  it — may confer in-game power: access yes, advantage never.
- **Respect for player time**: The engine MUST NOT ship dark patterns —
  no engagement traps, FOMO mechanics, or grind engineered to retain rather
  than delight.
- **Low barrier to play**: Joining a world MUST remain easy and free of
  unnecessary walls — no account hurdles, installs, or hardware demands
  beyond what the experience genuinely requires. The barrier includes
  ability: within the technical constraints available, the default
  experience MUST be playable by players with disabilities, and
  accessibility regressions are treated as defects.
- **Safety & dignity**: Moderation and safety tooling are core engine
  features. Every world MUST ship with real tools to protect player
  wellbeing; safety is never an optional add-on. (Safety concerns wellbeing
  within play; protection of data and accounts is security — Principle VIII.)

**Rationale**: Creators reach players through the engine. An engine that
permits player-hostile worlds damages every world built on it.

### III. Open Ecosystem, No Lock-In

The open source license is the legal floor, not the whole commitment. The
project additionally binds itself to:

- **No lock-in, ever**: Creators own their worlds and their data. They MUST
  always be able to leave, self-host, and take everything with them.
- **Open development**: Decisions, specs, and roadmaps happen in public.
  Community contribution is a first-class path, not an afterthought.
- **Protect the commons**: The engine's license MUST guarantee that
  improvements to the engine flow back to the ecosystem — running a
  modified engine means sharing those modifications. Enclosing the commons
  is not a permitted business model.
- **Licensing policy**: The engine core (server and the systems that make a
  world run) is licensed AGPL-3.0 — network copyleft is what makes the
  commons guarantee real for hosted software. The ecosystem edges — client
  SDKs, protocol definitions, and creator tooling — are licensed Apache-2.0
  so that building clients, tools, and integrations carries no license
  friction. Each repository declares which side of the line it sits on;
  moving the line is a constitutional amendment.
- **World-content boundary**: A creator's world — its content, data, and
  scripts written against the creator-facing API — is NOT a derivative work
  of the engine. Copyleft never reaches into a creator's world; creators
  license their own worlds however they choose. This boundary MUST be
  stated explicitly alongside the engine's license.
- **Worlds outlive engine versions**: Once the engine reaches 1.0, upgrades
  MUST NOT orphan existing worlds — every breaking change ships with a
  migration path. Before engine 1.0, breaking changes are permitted with
  clear notice to creators.

**Rationale**: Creators will only invest years building worlds on Odyssey if
the project can never hold those worlds hostage.

### IV. Spec-First, Centrally Governed

This repository is the centralized spec for the multi-repository Odyssey
project and is the source of truth for what the engine is.

- Features MUST start as specifications in this repository before
  implementation begins in any repository.
- Specifications describe player and creator experience and intended
  behavior; implementation and technology choices belong downstream in plans,
  not in specs or this constitution.
- When a repository's practice conflicts with a ratified spec or this
  constitution, the spec wins; the repository MUST change or the spec MUST be
  amended first.

**Rationale**: With work spread across repositories, a single authoritative
spec is the only defense against drift in what "Odyssey" means.

### V. Tested to Be Trusted

Behavior is not done until tests prove it.

- Every repository MUST enforce quality gates that block merging untested
  behavior.
- Acceptance scenarios in specs MUST be verifiable, and implementations MUST
  demonstrate them with automated tests.
- A bug fix MUST include a test that fails without the fix.

**Rationale**: Persistent worlds compound state over years; defects that
corrupt a living world are far costlier than the tests that prevent them.

### VI. Docs as a Feature

Documentation for creators and players ships with the feature, not after it.

- A feature without its creator- and/or player-facing documentation is
  unfinished and MUST NOT be considered complete.
- Documentation is reviewed with the same rigor as the change it describes.

**Rationale**: The engine succeeds only when creators who didn't build it can
use it; undocumented capability is invisible capability.

### VII. Simplicity & YAGNI

Build the simplest thing that serves the experience.

- Complexity MUST be justified against the principles above — concretely,
  in the Complexity Tracking section of an implementation plan — or removed.
- Speculative generality is rejected by default: the engine is opinionated
  (Principle I), so "someone might want to configure this" is not a
  justification.

**Rationale**: A small, opinionated engine maintained by a community must
spend its complexity budget only where the experience demands it.

### VIII. Secure by Default

Security protects what players, creators, and operators entrust to a world —
their data, identities, and credentials. It is distinct from safety
(Principle II), which protects wellbeing within play; security guards against
compromise from outside the rules of play.

- The engine MUST protect accounts, credentials, and personal data against
  compromise. Authentication and data protection are engine responsibilities,
  never left for creators to build or bolt on.
- Worlds are hosted by hobbyists (Engine Identity): a default deployment
  MUST be secure without requiring security expertise from the operator.
  Insecure configurations require deliberate, documented opt-out — the
  secure path is always the easy path.
- Data collection is minimized: the engine MUST NOT collect or retain more
  personal data than the experience requires, and operators MUST be able to
  honor a player's request to delete their data.
- Vulnerabilities take precedence over feature work. Fixes MUST be disclosed
  responsibly so that every operator can patch before details are public.

**Rationale**: Players hand their data and identities to hobbyist operators
they've never met. That trust is only sustainable if the engine — not each
operator's expertise — is what keeps them secure.

## Engine Identity

These identity commitments bound what Odyssey is. They are experience-level
constraints, binding on all repositories; changing them requires a
constitutional amendment.

- **Persistent, shared worlds**: An Odyssey world exists and evolves
  independently of any individual player's session, and is experienced
  together with others.
- **Small communities**: Worlds are designed around roughly 10–100 concurrent
  players and MUST remain practical for a hobbyist to host and operate
  affordably.
- **Web-first play**: Joining a world requires nothing more than a web
  browser.
- **Creators build content, not systems**: The unit of creation on Odyssey is
  a world — its places, people, stories, and rules expressed through engine
  capabilities — not a new game architecture.

## Development Workflow

- **Lifecycle**: Constitution → feature specification (this repository) →
  implementation plan → tasks → implementation, per the Spec Kit workflow.
  Implementation plans MUST pass the Constitution Check gate against this
  document before design and again after it.
- **Cross-repository coordination**: Work affecting more than one repository
  MUST be specified here first; downstream repositories track their specs'
  ratified versions.
- **Review**: Every PR in every repository is reviewed for compliance with
  this constitution. Reviewers MUST block changes that violate a principle
  unless a documented, justified exception is recorded in the plan's
  Complexity Tracking.
- **Quality gates**: Tests (Principle V) and documentation (Principle VI)
  are merge requirements, not follow-ups.

## Governance

This constitution supersedes all other practices in every Odyssey repository.
Conflicts resolve in the constitution's favor.

- **Decision model — founder-led, evolving**: The founder, Christopher
  Lowenthal, holds final decision authority while the project is young. Community input is actively
  sought and decisions are made in public (Principle III). The project
  commits to moving toward shared governance as a contributor community
  forms; that transition is itself a constitutional amendment.
- **Amendments**: Amendments are proposed publicly as PRs against this file,
  discussed in the open, and ratified by the founder. Each amendment MUST
  update the version below per semantic versioning (MAJOR: principle
  removals or incompatible redefinitions; MINOR: new principles or material
  expansions; PATCH: clarifications and wording), record the amendment date,
  and propagate changes to dependent templates and repositories.
- **Compliance review**: All specs, plans, and PRs are checked against this
  document. Complexity and exceptions MUST be justified in writing in the
  plan's Complexity Tracking section.

**Version**: 0.4.0 | **Ratified**: TODO(RATIFICATION_DATE): pending — draft, will be ratified as v1.0.0 | **Last Amended**: 2026-06-05
