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

| Repository | License side | Domain | Charter |
|------------|--------------|--------|---------|
| `server` | AGPL-3.0 (engine core) | The authoritative engine that runs persistent, shared worlds. | [server.md](./server.md) |
| `client` | Apache-2.0 (ecosystem edge) | The web-first player client — the window into a world run elsewhere. | [client.md](./client.md) |
| `proto` | Apache-2.0 (ecosystem edge) | The shared protocol contract between Odyssey applications. | [proto.md](./proto.md) |
| `admin-tools` | Apache-2.0 (ecosystem edge) | Operator and host-facing tooling for running a server. | [admin-tools.md](./admin-tools.md) |
| `registry` | AGPL-3.0 (engine core) | Identity and server-directory service that game servers register with. | [registry.md](./registry.md) |
| `speckit` | AGPL-3.0 (engine core) | Central governance and specification for the Odyssey project. | [speckit.md](./speckit.md) |

**Adding a repository:** record the decision in `decisions.md`, add a row here,
author its charter from [`_template.md`](./_template.md), and add a compact
`CHARTER.md` stub in the new repository pointing back to its charter here.
