# Repository Charters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a repository-charter system — a self-contained, tech-free charter per repo governed centrally in `speckit`, introduced by a MINOR constitution amendment (v1.1.0 → v1.2.0) plus governance artifacts and a compact per-repo stub — so cross-repo work can be attributed to the right repository.

**Architecture:** Authority lives centrally: `speckit/charters/` holds the authoritative charter for every repo, a registry, a growing routing-decisions log, and a template. Each application repo carries a compact `CHARTER.md` stub that links to its authoritative charter at its **live** location on `speckit main`. Routing is not pre-authored; unclear cases are decided by the founder and recorded, then optionally promoted into a charter's scope.

**Tech Stack:** Markdown governance artifacts; the SpecKit `speckit-constitution` skill for the amendment; git worktrees for the bare application repos.

**Design record:** `speckit/docs/design/2026-07-01-repository-charters-design.md`

## Global Constraints

Every task's requirements implicitly include these:

- **Self-contained charters:** a charter describes only its own repository and never names or redirects to another. (Referencing the shared registry/decisions log is fine — that is governance infrastructure, not scope routing.)
- **Constitution altitude:** no languages, runtimes, transports, or implementation choices in any charter. Describe responsibility in the constitution's register.
- **Out of scope = pure disclaimer:** list what the repo does *not* own, with **no** "→ goes to X" redirect.
- **License sides (fixed):** `server`, `registry`, `speckit` → AGPL-3.0 (engine core); `client`, `proto`, `admin-tools` → Apache-2.0 (ecosystem edge).
- **Stub = pure pointer:** a per-repo `CHARTER.md` is just a link to the charter at its **live location on `speckit main`** (`/blob/main/…`, never a pinned commit) — it restates no attributes. Domain and scope live in the charter; a repo's license is authoritatively declared by its own `LICENSE` file.
- **A task belongs to exactly one repository.** Features may span repos (plan's Repositories Affected table); tasks do not.
- **No automation/enforcement** (YAGNI): no CI gate, no stub↔charter auto-sync.
- **Amendment is MINOR** (1.1.0 → 1.2.0): use the `speckit-constitution` skill; do not hand-edit `constitution.md`.
- **Repositories Affected (this feature):** `speckit` (primary — amendment + artifacts), then `server`, `client`, `proto`, `admin-tools`, `registry` (each gains a stub, after the `speckit` work merges).

---

## Phase 1 — `speckit` PR (branch: `repository-charters`, off `main`)

Commit 1 (design record) is already on the branch. Tasks 1–3 add to it; the phase ends with one PR.

### Task 1: Constitution v1.2.0 amendment

**Files:**
- Modify: `speckit/.specify/memory/constitution.md` (via the `speckit-constitution` skill — do not hand-edit)
- Review (expect no change): `speckit/.specify/templates/plan-template.md`, `speckit/.specify/templates/tasks-template.md`, `speckit/.specify/templates/spec-template.md`

**Interfaces:**
- Produces: constitution v1.2.0 containing a "Repository Charters" rule under Development Workflow; a refreshed Sync Impact Report; version footer `1.1.0 → 1.2.0`. Later tasks and the registry cite this rule.

- [ ] **Step 1: Invoke the `speckit-constitution` skill** with this amendment intent — add a **Repository Charters** subsection under `## Development Workflow`, immediately after "Cross-repository coordination", with this content:

  > - **Repository Charters**: Every repository has a charter, governed centrally in this repository, declaring its domain, its license side (Principle III), and its in-scope and out-of-scope responsibilities. A charter is self-contained — it describes only its own repository and never redirects to another. When the repository a piece of work belongs to is not strictly clear from the charters, the founder decides and the decision is recorded in the charter decisions log; recorded patterns MAY be promoted into a charter's scope. Standing up a new repository is one such recorded decision. A task belongs to exactly one repository: a feature MAY span repositories (declared in a plan's Repositories Affected table) but its task breakdown MUST decompose cross-repository work until each task lands in a single repository.

- [ ] **Step 2: Verify the amendment mechanics.** Confirm in `constitution.md`:
  - The Sync Impact Report header shows `Version change: 1.1.0 → 1.2.0 (MINOR: …)` and lists the new subsection.
  - The version footer reads `**Version**: 1.2.0 | **Ratified**: 2026-06-05 | **Last Amended**: 2026-07-01`.
  - The three templates are listed as checked; expect "no change" — the Repositories Affected table (plan) and `[Repo]` tag (tasks) added in v1.1.0 remain the routing mechanism; charters feed those decisions, they do not alter the templates.

  Run: `grep -n "Repository Charters\|Version.*1.2.0\|Last Amended.*2026-07-01" speckit/.specify/memory/constitution.md`
  Expected: matches for the new subsection heading, the 1.2.0 version, and the 2026-07-01 amendment date.

- [ ] **Step 3: Commit**

```bash
git add speckit/.specify/memory/constitution.md speckit/.specify/templates/
git commit -m "Amend constitution to v1.2.0: Repository Charters"
# (append the required Co-Authored-By / Claude-Session trailers)
```

### Task 2: Charter scaffold — template, registry, decisions log

**Files:**
- Create: `speckit/charters/_template.md`
- Create: `speckit/charters/README.md`
- Create: `speckit/charters/decisions.md`

**Interfaces:**
- Produces: the four-section charter template (consumed by Task 3), the registry table (Task 3 fills domains/links for all six repos), and `decisions.md` seeded with decision #1 (the `speckit` license-side call).

- [ ] **Step 1: Create `speckit/charters/_template.md`**

```markdown
# <Repository> Charter

> Authoritative charter for the `<repo>` repository, governed centrally in
> `speckit` (Constitution → Development Workflow → Repository Charters). See the
> registry: [`README.md`](./README.md). Ambiguous routing is recorded in
> [`decisions.md`](./decisions.md), never here.

## Domain

<One paragraph: this repository's responsibility, on its own terms. No
languages, runtimes, or implementation.>

## License side

<AGPL-3.0 (engine core) | Apache-2.0 (ecosystem edge)> — <one-line rationale,
tied to Constitution Principle III.>

## In scope

<!-- Grows as edge cases are settled. Responsibilities this repository owns. -->

- ...

## Out of scope

<!-- Grows as edge cases are settled. Pure disclaimers — NO redirect to another
     repository. Prevents work being mis-assigned here. -->

- ...
```

- [ ] **Step 2: Create `speckit/charters/README.md`** (registry)

```markdown
# Repository Charters

Every Odyssey repository has a charter here — the authoritative statement of
what belongs in it. Charters are governed centrally (Constitution →
Development Workflow → Repository Charters) and are **self-contained**: each
describes only its own repository and never redirects to another.

**Finding the owning repository:** read the charters and find the one whose
**In scope** claims the work. Exactly one match → that repository. Zero, or
more than one → an unclear-routing case: the founder decides and the decision
is recorded in [`decisions.md`](./decisions.md). Standing up a new repository
is one such decision.

**A task belongs to exactly one repository.** A feature may span repositories —
declared in a plan's "Repositories Affected" table — but its tasks decompose
until each lands in a single repository.

| Repository | Charter |
|------------|---------|
| `server` | [server.md](./server.md) |
| `client` | [client.md](./client.md) |
| `proto` | [proto.md](./proto.md) |
| `admin-tools` | [admin-tools.md](./admin-tools.md) |
| `registry` | [registry.md](./registry.md) |
| `speckit` | [speckit.md](./speckit.md) |

**Adding a repository:** record the decision in `decisions.md`, add a row here,
author its charter from [`_template.md`](./_template.md), and add a compact
`CHARTER.md` stub in the new repository pointing back to its charter here.
```

- [ ] **Step 3: Create `speckit/charters/decisions.md`** (seeded)

```markdown
# Charter Routing Decisions

When the repository a piece of work belongs to is not strictly clear from the
charters, the founder decides and the decision is recorded here. Recorded
patterns may later be promoted into a charter's In/Out-of-scope. Format:

> **#N (YYYY-MM-DD) — <question>.** Decision: <outcome>. Rationale: <why>.

---

**#1 (2026-07-01) — Which license side is `speckit` on?** Decision: AGPL-3.0
(engine core), the same side as `server`. Rationale: `speckit` is central
governance, not an ecosystem edge; it has no need to promote an ecosystem of
extension and experimentation, so the friction-reduction reason the edge repos
are Apache-2.0 does not apply, and it aligns with the copyleft engine core.
```

- [ ] **Step 4: Verify the scaffold.** Run: `ls speckit/charters/ && grep -c "|" speckit/charters/README.md`
  Expected: `_template.md`, `README.md`, `decisions.md` present; the registry table has all six repo rows (≥ 8 pipe-bearing lines counting header + separator + 6 rows).

- [ ] **Step 5: Commit**

```bash
git add speckit/charters/_template.md speckit/charters/README.md speckit/charters/decisions.md
git commit -m "charters: add template, registry, and decisions log"
# (append trailers)
```

### Task 3: Author the six charters

Each file follows `_template.md` exactly (four sections). Content below is the seed — In/Out-of-scope will grow later. **Verify each has all four sections and names no other repository.**

**Files:**
- Create: `speckit/charters/server.md`, `client.md`, `proto.md`, `admin-tools.md`, `registry.md`, `speckit.md`

**Interfaces:**
- Consumes: `_template.md` (Task 2). Produces: the six authoritative charters the registry links to and the Phase 2 stubs point at.

- [ ] **Step 1: Create `speckit/charters/server.md`**

```markdown
# server Charter

> Authoritative charter for the `server` repository, governed centrally in
> `speckit`. Registry: [`README.md`](./README.md). Routing: [`decisions.md`](./decisions.md).

## Domain

The Odyssey engine — the authoritative server that runs persistent, shared
worlds: it simulates the world, holds authoritative state, enforces the rules
of play, and persists worlds over time.

## License side

AGPL-3.0 (engine core) — the server is the system that makes a world run;
network copyleft is what keeps the commons guarantee real for hosted software
(Principle III).

## In scope

- Authoritative world state and simulation
- Game rules and systems
- Player sessions and authentication
- World persistence and migration
- In-world moderation and safety tooling
- Server-side enforcement of fairness

## Out of scope

- Presentation, rendering, and input handling
- The shared protocol contract
- Operator and host-facing tooling
- Cross-server identity and discovery
```

- [ ] **Step 2: Create `speckit/charters/client.md`**

```markdown
# client Charter

> Authoritative charter for the `client` repository, governed centrally in
> `speckit`. Registry: [`README.md`](./README.md). Routing: [`decisions.md`](./decisions.md).

## Domain

The web-first player client — the player's window into a world run elsewhere.
It presents world state and captures player intent, delivered web-first per the
constitution's Engine Identity, and holds no authority over the world.

## License side

Apache-2.0 (ecosystem edge) — a client carries no license friction for people
building on the ecosystem (Principle III).

## In scope

- Rendering and presentation of world state
- Capturing and sending player input and intent
- The default experience's UX and accessibility

## Out of scope

- Authoritative world state or rules
- World persistence
- The shared protocol contract
- Operator and host-facing tooling
```

- [ ] **Step 3: Create `speckit/charters/proto.md`**

```markdown
# proto Charter

> Authoritative charter for the `proto` repository, governed centrally in
> `speckit`. Registry: [`README.md`](./README.md). Routing: [`decisions.md`](./decisions.md).

## Domain

The shared protocol contract — the message definitions and generated bindings
that let Odyssey applications interoperate. Its whole reason to exist is to be
the agreed contract between the applications that speak it.

## License side

Apache-2.0 (ecosystem edge) — the protocol must be frictionless to build
against (Principle III).

## In scope

- Protocol and message schema definitions
- Generated bindings
- Versioning of the contract

## Out of scope

- Game or business logic
- Transport and runtime behavior
- Anything internal to a single application
```

- [ ] **Step 4: Create `speckit/charters/admin-tools.md`**

```markdown
# admin-tools Charter

> Authoritative charter for the `admin-tools` repository, governed centrally in
> `speckit`. Registry: [`README.md`](./README.md). Routing: [`decisions.md`](./decisions.md).

## Domain

Operator and host-facing tooling for the people running an Odyssey server —
administration, operations, and world management that happen outside of play.

## License side

Apache-2.0 (ecosystem edge) — operator tooling is an ecosystem edge and should
carry no license friction (Principle III).

## In scope

- Server administration and operations tooling
- World and content management for operators
- Host-facing diagnostics

## Out of scope

- Authoritative engine and game logic
- The player-facing experience
- Cross-server identity and discovery
```

- [ ] **Step 5: Create `speckit/charters/registry.md`**

```markdown
# registry Charter

> Authoritative charter for the `registry` repository, governed centrally in
> `speckit`. Registry: [`README.md`](./README.md). Routing: [`decisions.md`](./decisions.md).

## Domain

The identity and server-directory service that Odyssey game servers register
with — how worlds are discovered and how identity is anchored across servers.

## License side

AGPL-3.0 (engine core) — the registry is a world-running system of the engine;
network copyleft protects the commons for hosted software (Principle III).

## In scope

- Server registration and the discovery directory
- Cross-server identity anchoring
- The service's own authentication and data protection

## Out of scope

- Running or simulating a world
- Player-facing presentation
- Operator and host-facing tooling
- The shared protocol contract
```

- [ ] **Step 6: Create `speckit/charters/speckit.md`**

```markdown
# speckit Charter

> Authoritative charter for the `speckit` repository, governed centrally in
> `speckit` (this repository). Registry: [`README.md`](./README.md). Routing:
> [`decisions.md`](./decisions.md).

## Domain

Central governance and specification for the Odyssey project — the constitution,
feature specifications and their derived artifacts, the repository charters, and
the shared CI/CD reusable workflows.

## License side

AGPL-3.0 (engine core) — recorded as decision #1: central governance is not an
ecosystem edge and needs no low-friction on-ramp for extension, so it aligns
with the copyleft engine core.

## In scope

- The constitution and its amendments
- Feature specifications and their derived artifacts
- Repository charters and the decisions log
- Shared CI/CD reusable workflows and release/versioning policy

## Out of scope

- Application or runtime code for any engine or edge product
- Per-repository implementation beyond the shared CI/CD interface
```

- [ ] **Step 7: Verify the charters.**
  - Every file has the four sections. Run: `for f in server client proto admin-tools registry speckit; do echo "== $f =="; grep -c "^## \(Domain\|License side\|In scope\|Out of scope\)" speckit/charters/$f.md; done`
    Expected: each prints `4`.
  - Self-containment smell test — no charter names another repo. Run: `for f in server client proto admin-tools registry speckit; do echo "== $f =="; grep -nE "server|client|proto|admin-tools|registry|speckit" speckit/charters/$f.md | grep -viE "charter for the \`$f\`|this repository|README|decisions|^.*# $f "; done`
    Expected: no line that redirects scope to another repo (matches limited to the header/governance-infra references are fine; a hit inside In/Out-of-scope naming another repo is a defect — reword to a pure disclaimer).

- [ ] **Step 8: Commit**

```bash
git add speckit/charters/server.md speckit/charters/client.md speckit/charters/proto.md speckit/charters/admin-tools.md speckit/charters/registry.md speckit/charters/speckit.md
git commit -m "charters: author the six repository charters (seed)"
# (append trailers)
```

### Task 4: Open the Phase 1 PR

- [ ] **Step 1: Push and open the PR**

```bash
git push -u origin repository-charters
gh pr create --repo Odyssey-Classic/speckit --base main --head repository-charters \
  --title "Repository charters + constitution v1.2.0" \
  --body "See docs/design/2026-07-01-repository-charters-design.md. Amends the constitution to v1.2.0 (Repository Charters) and adds speckit/charters/ (registry, template, six charters, decisions log). Per-repo CHARTER.md stubs follow as separate PRs once this merges."
```

- [ ] **Step 2: Verify** the PR shows the design record, the v1.2.0 amendment, and all `charters/` files, and that CI (spec 001 gates) is green. Request review; merge per project governance.

---

## Phase 2 — per-repo stub PRs (each after Phase 1 merges)

Do not start until Phase 1 is merged to `speckit main`, so each stub's link resolves. Each application repo is **bare** — use a worktree. `speckit` needs **no stub** (its charter is already in-repo at `charters/speckit.md`).

### Task 5: Add `CHARTER.md` stub to each application repo

Repeat for each of: `server`, `client`, `proto`, `admin-tools`, `registry`. The stub is identical bar the per-repo charter link; it restates no attributes.

**Files (per repo):**
- Create: `<repo>/CHARTER.md`

- [ ] **Step 1: Create a worktree off the repo's `main`**

```bash
git -C <repo> worktree add ../<repo>-charter-stub -b charter-stub origin/main
```

- [ ] **Step 2: Create `CHARTER.md`** in the worktree (example shown for `server`; swap only the `<repo>.md` in the link per repo):

```markdown
# Charter

This repository's charter — what belongs here and what doesn't — is governed
centrally in `speckit`, the single source of truth:

https://github.com/Odyssey-Classic/speckit/blob/main/charters/server.md

The link tracks `main`, so it always reflects the current charter.
```

- [ ] **Step 3: Verify** the link path matches the repo (`…/charters/<repo>.md`) and points at `/blob/main/` (not a commit SHA), and that the stub restates no attributes (pure pointer). Run: `grep -n "blob/main/charters" <repo>-charter-stub/CHARTER.md`
  Expected: one match with the correct `<repo>.md`.

- [ ] **Step 4: Commit, push, open PR**

```bash
git -C ../<repo>-charter-stub add CHARTER.md
git -C ../<repo>-charter-stub commit -m "Add CHARTER.md stub pointing to central charter"
# (append trailers)
git -C ../<repo>-charter-stub push -u origin charter-stub
gh pr create --repo Odyssey-Classic/<repo> --base main --head charter-stub \
  --title "Add repository charter stub" \
  --body "Compact stub pointing to the authoritative charter in speckit (charters/<repo>.md). Follows the repository-charters change in speckit."
```

- [ ] **Step 5: Clean up the worktree** after merge: `git -C <repo> worktree remove ../<repo>-charter-stub`

---

## Self-review notes

- **Design coverage:** amendment (Task 1) ✓; registry + template + decisions log (Task 2) ✓; six charters incl. `speckit`=AGPL decision #1 (Task 3) ✓; live-link stubs, no pin (Task 5) ✓; cross-repo decomposition into Phase 1 + per-repo PRs ✓; no automation/enforcement (out of scope) ✓.
- **Altitude:** charter bodies name no languages/runtimes; `proto`'s "generated bindings" describes responsibility, not a toolchain.
- **Self-containment:** every charter's Out-of-scope is a pure disclaimer; Task 3 Step 7 checks it.
