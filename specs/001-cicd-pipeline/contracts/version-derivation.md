# Contract: Version Derivation

How any build computes its version from git alone — deterministic, no human
input (D3, FR-008/010).

## Algorithm

```
tag = git describe --tags --match 'v[0-9]*' --long --dirty
```

| Source state | Derived `semver` | `derivation` | `is_prerelease` |
|--------------|------------------|--------------|-----------------|
| Commit is exactly tag `v1.2.3` | `1.2.3` | `exact-tag` | false |
| 5 commits past `v1.2.3`, sha `abc1234` | `1.2.3-5-gabc1234` | `git-describe` | true |
| No tags yet | `0.0.0-<n>-g<sha>` | `git-describe` | true |
| Working tree dirty (CI: forbidden) | append `-dirty` → **fail the build** | — | — |

## Rules

- **R1**: A released artifact MUST build from an `exact-tag` state; a `-dirty`
  or `git-describe` version MUST NOT be published as a release (FR-012).
- **R2**: The derived `semver` MUST be embedded in the artifact and reportable
  by the running application (FR-008, SC-002, US2 scenario 2).
- **R3**: `MAJOR == 0` ⇒ `pre_1_0 = true` ⇒ the compatibility disclaimer is
  attached to release notes and `--version` output (FR-011).
- **R4**: No path allows a human to supply a number that isn't anchored to a
  tag (FR-010); the `version` override input must itself be a valid SemVer tag
  that exists.

## Artifact embedding (per-adapter)

The adapter declares how to inject `semver` + `commit_sha` at build time.
Example (Go): `-ldflags "-X main.version=$SEMVER -X main.commit=$SHA"`.
Each application MUST expose a version report (e.g., `--version` / an endpoint /
a build-info file) — the surface is the adapter's choice; the presence is
mandatory (R2).
