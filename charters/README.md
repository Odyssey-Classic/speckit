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
