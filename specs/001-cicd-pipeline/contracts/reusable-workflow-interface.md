# Contract: Reusable Workflow Interface

The interface a consuming repository programs against. Stable across policy
versions within a MAJOR; breaking input changes bump the policy MAJOR (D10).

## `gate.yml` (called on pull_request)

**Caller example** (in a consuming repo, the *entire* required content):

```yaml
# .github/workflows/ci.yml
on: { pull_request: {} }
jobs:
  gate:
    uses: Odyssey-Classic/speckit/.github/workflows/gate.yml@policy-v1
    with:
      adapter: go            # which ecosystem adapter to use
      license_side: agpl-core
    # no other configuration permitted — zero bespoke gate logic (SC-005)
```

**Inputs**:

| Input | Required | Type | Meaning |
|-------|----------|------|---------|
| `adapter` | yes | string | Adapter id under `adapters/` (`go`, `node`, `docs-only`, …). |
| `license_side` | yes | enum | `agpl-core` \| `apache-edge` (Constitution III). |
| `policy_overrides` | no | — | **Disallowed**; present only to fail loudly if set. |

**Behavior**:
- Runs every required category from the pinned `gate-policy.yml`.
- Each category → `run-gate` composite → adapter command → normalized
  pass/fail.
- Security category diffs against branch baseline (D12).
- Emits a single definitive pass/fail status per category, automatically, with
  no manual trigger (SC-003).

**Outputs**: GitHub check runs (one per category) used by branch protection.

## `release.yml` (called on tag push / dispatch)

**Inputs**:

| Input | Required | Type | Meaning |
|-------|----------|------|---------|
| `adapter` | yes | string | Ecosystem adapter for the build. |
| `version` | no | string | Override; default derived from the triggering tag (D3). |

**Behavior (ordered, fail-closed)**: derive version → build reproducibly →
compose notes → sign/attest → publish one atomic Release (D5/D6/D7/D8).

**Outputs**: published `Application Release` (see data-model) or no visible
release at all.

## `spec-trace.yml` (called on pull_request)

**Inputs**: none beyond defaults. **Behavior**: validate Spec Reference
(see `spec-reference.md`); surface omission to reviewers unless exempt (D9).

## Compatibility contract

- Adding an optional input or a new adapter = policy MINOR.
- Removing/renaming an input, adding a required input, or changing a category's
  blocking semantics = policy MAJOR.
- Consumers pin a ref; nothing changes under them until they re-pin (D10).
