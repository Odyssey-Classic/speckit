# Contract: Spec Reference

How a PR declares the central spec it implements, and how the spec-trace gate
checks it (D9, FR-017, Constitution IV).

## Declaration (one of)

**Preferred — commit/PR trailer**, giving the `speckit` git commit SHA or tag
at which the spec was ratified (not a semver version):

```
Spec: 001-cicd-pipeline@spec-001-cicd-pipeline
```

or, pinning to a raw commit SHA:

```
Spec: 001-cicd-pipeline@4f2a9c1
```

**Or — PR body field** (rendered from the PR template):

```markdown
### Spec
- ID: 001-cicd-pipeline
- Ref: spec-001-cicd-pipeline
```

**Or — exemption label** on the PR:

```
maintenance          # must match a documented exemptions[].label in gate-policy.yml
```

## Gate behavior

| PR state | Result |
|----------|--------|
| Valid `(spec_id, spec_ref)` present | Pass. |
| Documented exemption label present | Pass. |
| Neither present | **Surface to reviewers** (failing/neutral check with guidance) — never silently passed (FR-017). |
| `spec_ref` does not resolve to a ratified revision of `spec_id` | Surface: ref not found / drift. |

## Validation rules

- `spec_id` MUST correspond to a directory under this repo's `specs/`.
- `spec_ref` MUST resolve, in `speckit` git history, to the ratified revision
  of that spec (the commit or tag at which it was ratified); a ref that
  doesn't match or resolve is surfaced for reviewer judgement (keeps drift
  visible, US4 scenario 3). No separate per-spec version-number scheme is
  introduced (FR-017) — the git commit/tag *is* the version.
- Exemption labels MUST exist in `gate-policy.yml.exemptions` (no ad-hoc
  exemptions — keeps SC-001/SC-007 honest).

## Why surfaced, not hard-blocked

The spec requires omissions to be *surfaced to reviewers unless exempt*, not an
absolute merge block — routine maintenance legitimately has no governing spec
(FR-017). Reviewers remain the decision point; the gate guarantees the
question is always asked.
