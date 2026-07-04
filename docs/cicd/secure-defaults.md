# Secure-by-Default Workflow Baseline

Status: **foundational convention** (T011). Every reusable workflow authored
later in this repo — `.github/workflows/gate.yml` (T016),
`.github/workflows/release.yml` (T035), `.github/workflows/spec-trace.yml`
(T045) — and every caller workflow a consuming repo adds MUST follow this
convention. It exists because this repo's pipeline holds credentials and
release-signing material on behalf of every downstream repo; a mistake here
is not local to one repo (Constitution [Principle
VIII](../../.specify/memory/constitution.md), spec FR-020, SC-008).

This document covers both halves of the baseline and is explicit about which
is which, because the two halves are enforced completely differently:

| Half | What it covers | Where it's enforced | Can a composite action set it? |
|---|---|---|---|
| **Workflow-level** | `permissions:`, trigger choice (`pull_request` vs `pull_request_target`), which job gets which secret, GitHub Environment gating | Hand-declared in each workflow's YAML, reviewed like any other change | **No** — a composite action runs *inside* an already-started job; it cannot grant, revoke, or inspect the job's token permissions or change what triggered it. |
| **Runtime** | Masking sensitive values in log output; refusing to proceed when a secret-bearing job is running in a context this repo does not trust | `.github/actions/harden/action.yml` — called as the first step of any job that touches a secret or signing key | Yes — this is exactly what the composite action does. |

Treat the table above as the honest boundary: nothing below claims the
composite action enforces something only `permissions:` can enforce, and
nothing below leaves a workflow-level control undocumented because "the
action handles it."

## 1. Workflow-level controls (hand-declared, not automatable)

### 1.1 Canonical `permissions:` block

Every workflow file in this repo — reusable (`gate.yml`, `release.yml`,
`spec-trace.yml`) and any caller workflow this repo ships as an example —
MUST declare a top-level `permissions:` block as the very first grant,
before any `jobs:`, and it MUST be no broader than:

```yaml
permissions:
  contents: read
```

This is the floor. Never omit `permissions:` (the implicit default is the
much broader repository-default token, which for many repos is
read/write) and never declare `permissions: write-all` anywhere in this
repo's workflows.

Any scope beyond `contents: read` MUST be:

- **narrow** — the single scope the job actually needs (`checks: write`,
  `id-token: write`, `pull-requests: write`, …), never a blanket grant;
  and
- **per-job**, declared on the job that needs it, not hoisted to the
  workflow level where every job in the file would inherit it.

```yaml
permissions:
  contents: read       # workflow-level floor — every job gets at most this

jobs:
  gate:
    permissions:
      contents: read   # this job needs nothing beyond the floor
      checks: write    # …except reporting its own check-run result
    steps: [...]
```

Expected per-workflow grants (recorded here so each future task has a
target to implement against, and so T049's pipeline-security audit has a
baseline to check against):

| Workflow | Job | Expected `permissions:` beyond the floor | Why |
|---|---|---|---|
| `gate.yml` | category-runner jobs | `checks: write` | emit one check run per gate category (FR-001, SC-003) |
| `release.yml` | build/derive/notes jobs | *(none — floor only)* | no secrets, no repo mutation |
| `release.yml` | sign/attest/publish job | `id-token: write`, `contents: write` | OIDC-based signing/attestation and creating the Release (FR-014, FR-016) |
| `spec-trace.yml` | trace-check job | `pull-requests: write` *(only if it comments; otherwise floor only)* | surface a missing spec reference to reviewers (FR-017) |

If an implementer finds a job needs a scope not listed here, that's a
signal to update this table in the same change — an undocumented scope
grant is exactly the drift this baseline exists to prevent.

### 1.2 Trigger choice: `pull_request` only, never `pull_request_target` with secrets

- `gate.yml` and `spec-trace.yml` run on `pull_request`. On GitHub Actions,
  a `pull_request` run triggered from a fork already does not receive
  repository/organization secrets (only a reduced, read-only
  `GITHUB_TOKEN`) — this is a platform guarantee, not something this repo
  configures. Rely on it, but don't rely on it *alone*: no job in
  `gate.yml` or `spec-trace.yml` may be given secrets in the first place,
  so there is nothing to leak even if that platform behavior ever changed
  for a given job.
- `pull_request_target` runs with the base repo's full secrets **and**
  privileged `GITHUB_TOKEN` even when triggered by a fork PR, while a
  careless checkout step can still pull in the fork's untrusted code. This
  repo's workflows MUST NOT use `pull_request_target` for any job that
  also checks out PR head content and holds secrets. `release.yml` and any
  signing-capable job are triggered by tag push / manual dispatch instead
  (contracts/reusable-workflow-interface.md), which sidesteps this
  entirely — there is no PR-authored code in a release run.
- The `harden` composite action (below) is the runtime backstop for this
  rule: pass `secrets-present: true` on any job that touches a secret, and
  it fails closed if that job is ever reached from a `pull_request_target`
  run or from a `pull_request` whose head is a fork.

### 1.3 Secret + signing-key attributability

- One secret per purpose, named for that purpose (e.g.
  `RELEASE_SIGNING_KEY`, not a shared `DEPLOY_SECRET` reused across
  unrelated jobs) — so a secret's access log line is self-explanatory.
- Signing/publish steps live in their own named job (e.g. `sign-and-publish`,
  not folded into a generically-named `build` job) so the workflow run's
  job list is itself an audit trail of which job touched which secret,
  satisfying "access to secrets and signing keys MUST be attributable and
  auditable" (FR-020).
- Prefer OIDC short-lived credentials (`id-token: write` +
  cloud/registry federation) over long-lived static secrets wherever the
  target supports it, so there is no standing credential to leak in the
  first place. Where a static secret is unavoidable (e.g. a signing key
  that must persist across releases), scope it to the single job/
  environment that needs it.

## 2. Runtime controls: `.github/actions/harden`

[`.github/actions/harden/action.yml`](../../.github/actions/harden/action.yml)
is the composite action every secret-bearing job calls as its first step.
It is intentionally small and dependency-free (no third-party marketplace
action — YAGNI: adding one would add supply-chain surface to the one place
that is supposed to reduce it) and does exactly two things a composite
action *can* do at runtime:

1. **Fails closed on untrusted fork-PR contexts.** Given
   `secrets-present: true`, it inspects the run's own `github.event_name`
   and (for `pull_request`) compares
   `github.event.pull_request.head.repo.full_name` against
   `github.repository`, exiting non-zero with a clear `::error::` before any
   later step runs if the context is `pull_request_target` (always), or a
   `pull_request` whose head repo differs from this repository. Comparing
   full names — rather than trusting the boolean `head.repo.fork` — makes the
   check fail **closed** when the head repo cannot be determined (e.g. a
   deleted source fork leaves the field empty): an empty value is not equal
   to this repository, so it is blocked. Any `secrets-present` value other
   than `true`/`false` is itself a hard error, so a typo can never silently
   disable the guard. A job with `secrets-present: false` (the default) is
   never blocked — this only guards jobs that actually declare they hold
   secrets.
2. **Masks caller-declared sensitive values.** Given a newline-separated
   `sensitive-values` input, it emits `::add-mask::<value>` for each
   non-blank line, so a value computed mid-job (not already a registered
   `secrets.*` entry GitHub masks automatically) never appears in plain
   text in the log.

Usage, as the first step of a secret-bearing job:

```yaml
jobs:
  sign-and-publish:
    permissions:
      contents: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: Odyssey-Classic/speckit/.github/actions/harden@policy-v1
        with:
          secrets-present: "true"
      - name: Sign release artifact
        run: ./scripts/sign.sh
        env:
          SIGNING_KEY: ${{ secrets.RELEASE_SIGNING_KEY }}
```

A job that never touches a secret does not need to call `harden` at all —
its default `secrets-present: false` would be a no-op, and every job
already inherits the workflow-level `permissions: contents: read` floor
from §1.1.

### Why context values are passed through `env:`, never interpolated into `run:`

The action reads `github.event_name`,
`github.event.pull_request.head.repo.full_name`, and `github.repository` via
step `env:` (`EVENT_NAME`, `HEAD_FULL_NAME`, `THIS_REPO`) and references them
as shell variables, rather than interpolating
`${{ github.event.pull_request.head.repo.full_name }}` directly into the
`run:` script text. This is the standard GitHub Actions script-injection
mitigation: a `run:` block is expanded by the Actions runner *before* the
shell ever sees it, so any expression interpolated directly into script text
is a code-injection vector once an attacker influences that context value.
The values used here are platform-set (not attacker-editable PR text like a
title or body), but routing them through `env:` costs nothing and keeps the
pattern uniform with how the *next* composite action in this repo
(`run-gate`, `compose-release-notes`, …) must handle any value that touches
PR-authored content.

## 3. What this baseline does not cover (out of scope for T011)

- Category-specific gate logic (which tools run for `security`, `quality`,
  etc.) — that's `policy/gate-policy.yml` and the adapters (T005–T010).
- The actual signing/attestation mechanism (`attest-and-verify`, T037) —
  this baseline says *who may reach a signing step*, not *how signing
  works*.
- T049's full pipeline-security audit, which verifies this baseline
  actually holds once `gate.yml`/`release.yml`/`spec-trace.yml` exist —
  this document is the standard that audit checks against.
