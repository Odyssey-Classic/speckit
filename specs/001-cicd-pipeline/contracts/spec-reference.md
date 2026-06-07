# Contract: Spec Reference

How a PR declares the central spec it implements, and how the spec-trace gate
checks it (D9, FR-017, Constitution IV).

## Declaration (one of)

**Preferred — commit/PR trailer**:

```
Spec: 001-cicd-pipeline@1.0.0
```

**Or — PR body field** (rendered from the PR template):

```markdown
### Spec
- ID: 001-cicd-pipeline
- Version: 1.0.0
```

**Or — exemption label** on the PR:

```
maintenance          # must match a documented exemptions[].label in gate-policy.yml
```

## Gate behavior

| PR state | Result |
|----------|--------|
| Valid `(spec_id, spec_version)` present | Pass. |
| Documented exemption label present | Pass. |
| Neither present | **Surface to reviewers** (failing/neutral check with guidance) — never silently passed (FR-017). |
| `spec_version` not a ratified version of `spec_id` | Surface: version not found. |

## Validation rules

- `spec_id` MUST correspond to a directory under this repo's `specs/`.
- `spec_version` SHOULD match a ratified version of that spec; a mismatch is
  surfaced for reviewer judgement (keeps drift visible, US4 scenario 3).
- Exemption labels MUST exist in `gate-policy.yml.exemptions` (no ad-hoc
  exemptions — keeps SC-001/SC-007 honest).

## Why surfaced, not hard-blocked

The spec requires omissions to be *surfaced to reviewers unless exempt*, not an
absolute merge block — routine maintenance legitimately has no governing spec
(FR-017). Reviewers remain the decision point; the gate guarantees the
question is always asked.
