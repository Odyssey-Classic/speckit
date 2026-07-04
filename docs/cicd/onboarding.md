# Onboarding: Adopting the Standard Gates in a New Repository

Status: **living guide** (T024). This is the FR-019 "documented, repeatable
procedure" for adopting Odyssey's shared merge gate — every step below is
configuration, not code; adoption authors **zero bespoke gate logic** (SC-005,
Constitution VI). If you find yourself writing shell logic to make a check
pass, stop — that decision belongs centrally in
[`policy/gate-policy.yml`](../../policy/gate-policy.yml) or an
[adapter](../../adapters/_template/adapter.yml), not in your repo's workflow
file.

The reference consumer for everything in this guide is this very repository:
[`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) is speckit's own
caller workflow, dogfooding the same procedure a new repo follows (the spec
repo is governed, not exempt from its own gate).

## 1. Pick your ecosystem adapter

The gate's four categories (`tests`, `quality`, `security`, `docs`) are fixed
centrally; only the *means* of satisfying them varies per ecosystem. Pick the
adapter id matching your repo, under
[`adapters/`](../../adapters/):

- `go` — [`adapters/go/adapter.yml`](../../adapters/go/adapter.yml)
- `node` — [`adapters/node/adapter.yml`](../../adapters/node/adapter.yml)
- `docs-only` — [`adapters/docs-only/adapter.yml`](../../adapters/docs-only/adapter.yml)
  (a governance/spec repo with no compiled code — this repo's own profile)

No adapter for your ecosystem yet? Author one from
[`adapters/_template/adapter.yml`](../../adapters/_template/adapter.yml)
first — see that template for the exact hook contract (`test`, `lint`,
`security`, `docs`, `build`, `version-embed`) and what must never live in an
adapter (thresholds, exemptions, bypass rules — those are policy-only,
Constitution Principle V).

## 2. Add the caller workflow

Add a single file, `.github/workflows/ci.yml`, in your repo:

```yaml
# .github/workflows/ci.yml
on: { pull_request: {} }

permissions:
  contents: read

jobs:
  gate:
    permissions:
      contents: read
      checks: write
    uses: Odyssey-Classic/speckit/.github/workflows/gate.yml@<pinned-ref>
    with:
      adapter: <your-adapter-id>       # e.g. go, node, docs-only
      license_side: <your-license-side>  # agpl-core | apache-edge
```

This is the *entire* required content — see
[`contracts/reusable-workflow-interface.md`](../../specs/001-cicd-pipeline/contracts/reusable-workflow-interface.md)
for the full input contract. Two inputs only:

- `adapter` — the id you picked in step 1.
- `license_side` — your repo's declared side per your repo's charter
  (Constitution Principle III): `agpl-core` (engine core) or `apache-edge`
  (ecosystem edge). Checked centrally by the `quality` category; never
  declare it per-adapter.

Do not add a third input, an extra job, or any step beyond this `uses:` call
— that would be bespoke gate logic (SC-005). If the gate as configured
doesn't fit your repo, that's a signal to propose a policy or adapter change
centrally, not to work around it locally.

The `permissions:` block matches exactly what `gate.yml`'s own jobs need
(the `contents: read` floor plus `checks: write` for the category checks) —
see [`secure-defaults.md`](./secure-defaults.md) §1.1. A reusable workflow
can never be granted more than the calling job itself holds, so this is also
the ceiling `gate.yml` runs under in your repo.

### Pinning `<pinned-ref>`

Reusable workflows and `policy/gate-policy.yml` are versioned together via
release tags on this repo (`policy-vX`, tracking [`policy/VERSION`](../../policy/VERSION);
see D10 in `research.md`). Pin an actual tag, e.g.:

```yaml
uses: Odyssey-Classic/speckit/.github/workflows/gate.yml@policy-v1
```

Never pin `@main` — a floating ref is non-reproducible and defeats the
drift-detection purpose of the pin (FR-018): your pinned ref *is* the policy
version your repo is recorded as running. Nothing changes under you until
you deliberately bump it. To upgrade, change the ref to the newer tag; that
edit is the entire upgrade procedure.

## 3. One-time repo setup: branch protection

This is a **repo-admin (or org-policy) step** — it cannot be done by adding
files alone, since GitHub branch protection lives in repo/org settings, not
in version-controlled workflow YAML.

1. Open a PR first (any PR) so the gate runs at least once — GitHub only
   offers a check name in the branch-protection picker after it has reported
   at least one run.
2. In the repo's branch protection settings for `main` (Settings → Branches
   → Branch protection rules), require these status checks before merging,
   one per gate category (the job name in `gate.yml` is `Gate / <category>`):
   - `Gate / tests`
   - `Gate / quality`
   - `Gate / security`
   - `Gate / docs`
3. Do not additionally require any check your own caller workflow doesn't
   produce — the four above are the complete required set for every repo
   (Constitution Principle V: the categories are centrally, uniformly
   decided).

## 4. When a gate fails

Each failing category surfaces its own reason on its own check run — you do
not need insider knowledge of this repo's scripts to read it (FR-005):

1. Open the failed PR's **Checks** tab and find the specific `Gate / <category>`
   check that failed.
2. Open that check run's **Summary** — the gate workflow writes a
   `### Gate category '<category>' failed` block there naming what failed and
   what passing requires (not just a raw exit code).
3. Fix the named thing and push again; the check re-runs automatically on
   the same PR (SC-003 — no manual re-trigger).

If a category fails because of something genuinely outside your control
(e.g. an infrastructure outage, a false positive), see the bypass process —
`policy/gate-policy.yml`'s `bypass` block and
[`secure-defaults.md`](./secure-defaults.md) — bypass is always attributable
and logged; it is never silent (FR-006, SC-001).

## Reference

- [`contracts/reusable-workflow-interface.md`](../../specs/001-cicd-pipeline/contracts/reusable-workflow-interface.md) — the full `gate.yml` input/output contract.
- [`contracts/gate-policy.schema.md`](../../specs/001-cicd-pipeline/contracts/gate-policy.schema.md) — what the four categories and their thresholds mean.
- [`secure-defaults.md`](./secure-defaults.md) — the `permissions:`/trigger baseline every caller workflow must follow.
- [`policy/gate-policy.yml`](../../policy/gate-policy.yml) and [`policy/VERSION`](../../policy/VERSION) — the current policy content and version this guide describes.
- [`adapters/_template/adapter.yml`](../../adapters/_template/adapter.yml) — authoring a new ecosystem adapter.
- [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) — this repo's own caller workflow, as a worked example.
