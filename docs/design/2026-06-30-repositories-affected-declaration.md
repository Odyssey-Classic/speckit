# Design & Amendment Record: "Repositories Affected" declaration

**Date**: 2026-06-30
**Status**: Implemented — Odyssey Constitution **v1.1.0** (MINOR amendment)
**Scope**: `speckit` governance — constitution + plan/tasks templates; worked-example
back-fill of `001-cicd-pipeline`.

> **Why this file exists.** It records the exact customizations Odyssey made to the
> SpecKit constitution and templates. SpecKit is an upstream tool; a future
> `specify`/SpecKit upgrade may regenerate or overwrite `.specify/templates/*` or
> `.specify/memory/constitution.md`. If that happens, use the verbatim blocks in
> **Modifications (verbatim)** to re-apply these changes — see **Reconstruction
> procedure** at the end.

## Problem

Odyssey specs are centralized in `speckit`, but a feature that spans multiple repos
(proto + client + server, etc.) declared *which repos it touches* nowhere.
Coordination was reconstructed from PRs and memory. Task routing, issue routing,
branch coordination, and review targeting all depend on knowing a feature's repo
blast-radius, and none of them can until it is declared.

## Decisions (locked with the founder)

1. **Ambition**: declarative now, automate later. Add the declaration; do NOT wire
   automation/enforcement (consumers such as `taskstoissues`/`spec-trace` are
   unbuilt). Honors Principle VII (YAGNI). Shape it to be machine-readable later.
2. **Location**: `plan.md` (a new section) + per-task tags in `tasks.md`. NOT the
   spec — "which repos" is an implementation detail, and specs stay technology-free
   (Principle IV).
3. **Governance weight**: MINOR constitution amendment, `1.0.0 → 1.1.0` (material
   expansion of Development Workflow → Cross-repository coordination).
4. **Refinement (surfaced by the 001 worked example)**: the per-task `[Repo]` tag
   supports a *"declare a default repo once + tag only the exceptions"* mode for
   features where one repo dominates — not only tag-every-task. Tagging all 51
   `speckit` tasks in 001 would have been pure noise.

## Modifications (verbatim) — the reconstruction source of truth

### 1. Constitution — `.specify/memory/constitution.md`

- Version line → `**Version**: 1.1.0 | **Ratified**: 2026-06-05 | **Last Amended**: 2026-06-30`
- Top-of-file Sync Impact Report updated to describe the `1.0.0 → 1.1.0` MINOR change.
- The *Development Workflow → Cross-repository coordination* bullet, final text:

> - **Cross-repository coordination**: Work affecting more than one repository MUST
>   be specified here first; downstream repositories track their specs' ratified
>   versions. A multi-repository feature's implementation plan MUST enumerate the
>   repositories it changes and their coordination order, and its task breakdown
>   MUST attribute each task to a repository — so cross-repo scope is declared up
>   front, not reconstructed from PRs.

### 2. plan-template — `.specify/templates/plan-template.md`

Insert after the **Technical Context** block, immediately before `## Constitution Check`:

```markdown
## Repositories Affected

<!--
  ACTION REQUIRED: List every Odyssey repository this feature CHANGES, in
  coordination order (what must merge/release first). A single-repo feature has
  one row. Repositories that are only *consulted* (not changed) belong in the
  notes column, not as rows. Same Order value = may proceed in parallel.

  REQUIRED for multi-repository features per Constitution → Development Workflow
  → Cross-repository coordination (v1.1.0).
-->

| Order | Repository | What changes here | Depends on / coordinates with |
|-------|------------|-------------------|-------------------------------|
| 1     | [repo]     | [what changes]    | —                             |
```

### 3. tasks-template — `.specify/templates/tasks-template.md`

- Format line → ``## Format: `[ID] [P?] [Repo?] [Story] Description` ``
- Add this bullet under the format line (final, refined wording):

> - **[Repo]**: Which repository the task lands in (e.g., server, client, proto).
>   For multi-repository features, either tag every task or — when one repo
>   dominates — declare a default repo once (e.g., under Prerequisites) and tag only
>   the tasks that land elsewhere. Omit entirely for single-repo features.

- Add this bullet to the `## Notes` section:

> - [Repo] tags a task's repository in multi-repo features; when one repo dominates,
>   declare a default once and tag only the exceptions; omit for single-repo

## Explicitly out of scope (YAGNI)

- No spec-template change (repository scope is a plan concern).
- No automation, gate, or enforcement; `taskstoissues`/`spec-trace` untouched.
- No cross-repo branch coordination (separate, later).

## Worked example — `001-cicd-pipeline` back-fill

- `plan.md`: a `## Repositories Affected` table — `speckit` (primary; the entire
  central foundation) + `server` (proving-ground consumer, T050). The other four
  repos (`client`, `proto`, `admin-tools`, `registry`) are noted as future
  consumers, not changed by 001.
- `tasks.md`: default repo declared as `speckit`; only **T050** tagged `[server]`.
- This example is what surfaced decision #4 (the default-repo/exceptions mode).

## Reconstruction procedure (after a SpecKit tool upgrade)

1. Diff the three files above against this record.
2. If the upgrade overwrote them, re-apply the verbatim blocks in **Modifications**.
3. If the constitution was reset, restore the version line + Sync Impact Report
   (keep `1.1.0`, or increment if further amended).
4. Prefer routing the re-application through the `speckit-constitution` skill so
   template sync and the Sync Impact Report stay consistent — the `before_constitution`
   `git.initialize` hook is a no-op on this established repo and can be skipped.
