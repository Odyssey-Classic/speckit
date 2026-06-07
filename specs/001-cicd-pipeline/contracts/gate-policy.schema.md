# Contract: Gate Policy Schema

Schema for the central `policy/gate-policy.yml` (the Gate Policy entity). This
file is the single source of truth for gate categories, thresholds, and
exemptions; it is versioned and pinned by consumers (FR-003, FR-020).

## Shape

```yaml
policy_version: "1.0.0"          # equals the speckit tag consumers pin (D10)

categories:
  - name: tests                  # Constitution V
    required: true
    threshold: { must_pass: all }
  - name: quality                # lint/format + license-side declaration (Constitution III)
    required: true
    threshold: { must_pass: all, require_license_side: true }
  - name: security               # Constitution VIII
    required: true
    threshold:
      min_severity_block: high   # newly-introduced ≥ high blocks (FR-004, D12)
      preexisting: surface       # pre-existing: report, do not block
      include: [dependencies, secrets, sast]
  - name: docs                   # Constitution VI
    required: true
    threshold: { require_docs_for_user_facing_change: true }

exemptions:
  - label: maintenance           # spec-trace exemption (D9, FR-017)
    scope: spec-reference
    description: "Routine maintenance with no governing spec."

bypass:
  allowed: true                  # outages / false positives (Edge Cases)
  requires: admin-override       # attributable + logged; never silent (FR-006, D13)
  must_record: [actor, reason]
```

## Validation rules

- `policy_version` MUST be valid SemVer and unique per release (FR-020).
- The four categories (`tests`, `quality`, `security`, `docs`) MUST all be
  present with `required: true` (FR-002, Constitution V/VI/VIII).
- `security.threshold.min_severity_block` MUST be present (FR-004).
- Every `exemptions[].label` MUST have a `description` (no silent exemptions).
- `bypass.requires` MUST NOT be `none` and `must_record` MUST include `actor`
  and `reason` (FR-006, SC-001).

## Change semantics

- Loosening a threshold, removing a category, or adding a required category =
  **policy MAJOR** (consumer-visible behavior change).
- Adding an exemption label or tightening within an existing category = MINOR.
- Wording/description only = PATCH.
