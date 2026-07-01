# Contract: Release Metadata Schema

The metadata published with every Application Release, enabling discovery,
upgrade, and verification (D5/D7/D8, FR-013/014/016).

## Release object (one per release, atomic)

```yaml
application: server
version: "1.4.0"                 # exact-tag derived (version-derivation R1)
commit_sha: "abc1234…"
pre_1_0: false                   # if true, disclaimer block is REQUIRED (FR-011)
status: published                # published | deprecated (D14)

artifacts:
  - name: server_1.4.0_linux_amd64.tar.gz
    digest: "sha256:…"
    attestation: server_1.4.0_linux_amd64.intoto.jsonl   # provenance (D7)

release_notes:                   # FR-013
  changes: [ "…user-visible change…" ]
  upgrade_steps: [ "…" ]
  breaking_changes: [ "…" ]      # required section even if empty (1.0+)
  compatibility_disclaimer: null # MUST be set when pre_1_0 (FR-011)

verification:                    # FR-014 — how operators check authenticity
  method: "cosign verify / gh attestation verify"
  reference: "docs/cicd/verification.md"
```

## Validation rules

- **R1**: The release MUST NOT become visible until every `artifacts[]` entry
  has a `digest` and an `attestation`, and `release_notes` is present
  (atomic publish, FR-016).
- **R2**: `breaking_changes` MUST be an explicit section for `1.0+` releases
  (empty list allowed); for `pre_1_0`, `compatibility_disclaimer` MUST be
  non-null (FR-011, FR-013).
- **R3**: Each artifact MUST have a verifiable `attestation` and `digest`
  (FR-014).
- **R4**: A defective release transitions `status: published → deprecated`
  with a reason; it is never deleted (D14).
- **R5**: `version` MUST match an existing SemVer tag and the embedded artifact
  version (cross-check with version-derivation R2).

## Notes generation source

`release_notes` is composed from merged-PR titles/labels between the previous
and current tag (D8); a curated override may augment but not replace the
required sections.
