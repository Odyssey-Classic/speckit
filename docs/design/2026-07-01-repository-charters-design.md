# Repository Charters — Design

- **Date:** 2026-07-01
- **Status:** Proposed (design record for a forthcoming constitution amendment)
- **Decision authority:** Founder-led (Christopher Lowenthal); drafted with Claude Code
- **Related:** Constitution v1.1.0 (Development Workflow → Cross-repository
  coordination); Spec `001-cicd-pipeline`; design record
  `2026-06-30-repositories-affected-declaration.md`

## Problem

The constitution binds every repository and declares the AGPL-core /
Apache-edge licensing line, and Spec 001 added the *mechanisms* for routing
work across repositories: the plan's `## Repositories Affected` table, the
per-task `[Repo]` tag, and the standing rule to "never assume a repo count."

What is missing is any authoritative statement of **what belongs in each
repository**. Filling in a Repositories Affected table or tagging a task
`[server]` versus `[client]` today relies on tribal knowledge; overlaps
("this touches both server and client — where does the logic live?") and
novelty ("this fits no existing repo — do we make a new one?") have no
arbiter. The application repos carry only a one-line README each.

**Constraint:** the repository set is open-ended. Whatever we build must make
adding — or splitting off — a repository a cheap, well-defined move, not a
rewrite. This rules out any central design that hardcodes "the six repos" or
couples the repos to one another.

## Decision

Establish a **charter system**: a per-repository charter whose authority is
governed centrally in `speckit`, a deliberately minimal routing procedure that
*grows* from real cases, and a task-atomicity principle. It is introduced via a
MINOR constitution amendment plus governance artifacts authored directly in
`speckit` (the same way the constitution itself lives under `.specify/memory/`),
**not** as a numbered feature spec — charters are governance, not player- or
creator-facing features, so the specify → plan → tasks lifecycle (built around
acceptance scenarios) does not fit them.

## Principles

1. **Central authority, self-contained charters.** The authoritative charter
   for each repository lives in `speckit`. A charter describes only *its own*
   repository — it never names, redirects to, or depends on another charter.
   This is what keeps the repo set open-ended: adding a repo means adding one
   charter, never editing the others.
2. **Constitution altitude — no technical content.** A charter describes a
   repository's *responsibility* in the same experience/behavior register the
   constitution uses. No languages, runtimes, transports, or implementation
   choices. Those remain plan-level concerns.
3. **Routing accretes; it is never pre-authored.** There is no speculative
   routing table. When the owning repository for a piece of work is not
   strictly clear from the charters, the founder decides and the decision is
   **recorded**. Recorded patterns may later be promoted into a charter's
   scope. Scope lists themselves grow the same way.
4. **A task belongs to exactly one repository.** A *feature* may span
   repositories (declared in the plan's existing Repositories Affected table),
   but at the tasks stage cross-repo work is decomposed until every task is
   single-repo. This is already forced in practice — the repos are physically
   separate, so no commit or PR can span two of them — and it reinforces the
   constitution's existing per-task repository attribution. Work that cannot be
   attributed to one repository is either not split finely enough yet, or is an
   unclear-routing case for the founder to settle.

## Charter shape

Four fields. Two of them grow over time.

- **Domain** — a one-paragraph statement of the repository's responsibility,
  described on its own terms.
- **License side** — AGPL-3.0 (engine core) or Apache-2.0 (ecosystem edge),
  with a one-line rationale tying back to the constitution's licensing
  principle.
- **In scope** — the responsibilities this repository owns. *(grows)*
- **Out of scope** — responsibilities this repository explicitly disclaims,
  stated as a pure disclaimer with **no redirect** to where they go instead.
  *(grows)*

Routing is never a charter's job. To find the owner of a piece of work, look
for the charter whose **In scope** claims it. Exactly one match → done. Zero or
more than one → an unclear-routing case: the founder decides and the decision
is recorded. **Out of scope** entries exist to prevent false-positive matches —
to stop work being mis-assigned to a repo a reader might plausibly assume owns
it.

## Artifacts

### 1. Constitution amendment (v1.1.0 → v1.2.0, MINOR)

A new **Repository Charters** rule under Development Workflow, capturing:

- Every repository has a charter, governed centrally in `speckit`, declaring
  its domain, license side, and in/out-of-scope responsibilities.
- Charters are self-contained — a charter describes only its own repository and
  never redirects to another.
- A task belongs to exactly one repository; features may span repositories
  (declared in the plan's Repositories Affected table) but are decomposed until
  every task is single-repo.
- When the owning repository is not strictly clear from the charters, the
  founder decides and the decision is recorded in the charter decisions log;
  recorded patterns may be promoted into a charter's scope. Standing up a new
  repository is one such decision (add it to the registry and author its
  charter).
- Scope lists and the decisions log grow as edge cases surface.

MINOR is the correct bump: a material expansion of the Development Workflow, no
principle removed or redefined.

### 2. Governance artifacts under `speckit/charters/`

```
speckit/charters/
  README.md        # registry: pure index — table of every repo (name · link
                   #   to charter); links to decisions.md. No license side or
                   #   domain here — those live only in each charter, so the
                   #   registry cannot drift against them.
  _template.md     # the four-field charter shape
  server.md
  client.md
  proto.md
  admin-tools.md
  registry.md
  speckit.md
  decisions.md     # routing precedent log: case · decision · date · rationale
```

### 3. Per-repository stub

Each repository carries a compact `CHARTER.md` at its root: its one-line
domain, its license side, and a link to the authoritative
`speckit/charters/<repo>.md` at its **live location on `speckit` (not a pinned
revision)**.

Linking to the current charter — rather than a pinned ref — is deliberate. A
charter is living governance whose scope lists grow, so a reader should always
reach the latest; and pinning would force every repo's stub to be re-pinned
after each recorded scoping decision, reintroducing exactly the cross-repo
coupling the self-contained-charter principle removes. (This is unlike Spec
001's PR-to-spec reference, which pins a revision precisely because it is a
point-in-time authorization claim; a charter stub is a signpost to living
governance, like a link to the constitution.)

The stub carries only the two **stable** fields — domain and license side —
and the link; it deliberately excludes the growing scope. As a result,
recording a scoping decision touches only `speckit` (the stubs never move), and
a stub changes only when a repo's domain or license side changes — both rare,
deliberate events (a license-side change is itself a constitutional amendment).

## Initial license-side assignments

| Repository    | License side                | Note |
|---------------|-----------------------------|------|
| `server`      | AGPL-3.0 (engine core)      | Runs worlds |
| `registry`    | AGPL-3.0 (engine core)      | World-running system |
| `speckit`     | AGPL-3.0 (engine core)      | By recorded decision #1 |
| `client`      | Apache-2.0 (ecosystem edge) | |
| `proto`       | Apache-2.0 (ecosystem edge) | |
| `admin-tools` | Apache-2.0 (ecosystem edge) | |

## Seed charters (starting points — expected to grow)

These are initial drafts to validate the shape and give task-routing something
to consult on day one. They are seeds, not final: In/Out-of-scope lists are
expected to accrete as edge cases surface.

**`server`** — AGPL-3.0. *Domain:* the Odyssey engine — the authoritative
server that runs persistent, shared worlds. *In scope:* authoritative world
state and simulation; game rules and systems; player sessions and
authentication; world persistence and migration; in-world moderation and safety
tooling; server-side enforcement of fairness. *Out of scope:* presentation,
rendering, and input handling; the shared protocol contract; operator/host
tooling; cross-server identity and discovery.

**`client`** — Apache-2.0. *Domain:* the web-first player client — the window
into a world run elsewhere; it presents world state and captures player intent,
holding no authority over the world. *In scope:* rendering and presentation of
world state; capturing and sending player input/intent; the default
experience's UX and accessibility. *Out of scope:* authoritative world state or
rules; world persistence; the shared protocol contract; operator tooling.

**`proto`** — Apache-2.0. *Domain:* the shared protocol contract — the message
definitions and generated bindings that let Odyssey applications interoperate.
*In scope:* protocol and message schema definitions; generated bindings;
versioning of the contract. *Out of scope:* game or business logic; transport
and runtime behavior; anything internal to a single application.

**`admin-tools`** — Apache-2.0. *Domain:* operator and host-facing tooling for
people running an Odyssey server — administration, operations, and world
management outside of play. *In scope:* server administration and operations
tooling; world and content management for operators; host-facing diagnostics.
*Out of scope:* authoritative engine and game logic; the player-facing
experience; cross-server identity and discovery.

**`registry`** — AGPL-3.0. *Domain:* the identity and server-directory service
that Odyssey game servers register with — how worlds are discovered and how
identity is anchored across servers. *In scope:* server registration and the
discovery directory; cross-server identity anchoring; the registry's own
authentication and data protection. *Out of scope:* running or simulating a
world; player-facing presentation; operator host tooling; the shared protocol
contract.

**`speckit`** — AGPL-3.0. *Domain:* central governance and specification for
the Odyssey project — the constitution, feature specs/plans/tasks, repository
charters, and the shared CI/CD reusable workflows. *In scope:* the constitution
and its amendments; feature specifications and their derived artifacts;
repository charters and the decisions log; shared CI/CD reusable workflows and
release/versioning policy. *Out of scope:* application or runtime code for any
engine or edge product; per-repo implementation beyond the shared CI/CD
interface.

## Seed decisions log

`decisions.md` opens with its format and one recorded decision:

> **#1 (2026-07-01) — Which license side is `speckit` on?** Decision:
> AGPL-3.0 (engine core), the same side as `server`. Rationale: `speckit` is
> central governance, not an ecosystem edge; it has no need to promote an
> ecosystem of extension and experimentation, so the friction-reduction reason
> the edge repos are Apache-2.0 does not apply, and it aligns with the copyleft
> engine core.

## Out of scope for this design

- **No automation or enforcement.** No CI gate checks that a task's repo
  matches a charter, and nothing auto-syncs the per-repo stub to the
  authoritative charter. Consistent with Spec 001's deferral of cross-repo
  enforcement (YAGNI); may be revisited if drift becomes a real problem.
- **No pre-authored routing table.** Routing lives in the charters plus the
  growing decisions log, by design.
- **No template changes.** The plan's Repositories Affected table and the
  per-task `[Repo]` tag (added in v1.1.0) remain the routing mechanism;
  charters feed those decisions, they do not replace them.

## Execution outline

1. Amend the constitution to v1.2.0 via `speckit-constitution` (adds the
   Repository Charters rule; updates the Sync Impact Report).
2. Author the `speckit/charters/` artifacts (`README.md` registry,
   `_template.md`, the six charters, `decisions.md` seeded with decision #1).
3. Add the compact `CHARTER.md` stub to each repository, via worktrees (the
   application repos are bare).
