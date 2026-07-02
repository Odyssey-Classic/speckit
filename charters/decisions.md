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
