# Versioning Policy

Status: **binding policy** (T031). This is the project-wide rule for how every
Odyssey application names its builds and releases (FR-008, FR-011, Constitution
Principle VI — docs ship with the feature). It governs the same way
[`gate-policy.yml`](./gate-policy.yml) governs merge gates: centrally defined,
implemented identically by every repo.

The mechanics live in one place —
[`.github/actions/derive-version`](../.github/actions/derive-version/action.yml)
(the `derive-version` composite action and its
[`derive-version.sh`](../.github/actions/derive-version/derive-version.sh)) —
and the algorithm's contract is
[`contracts/version-derivation.md`](../specs/001-cicd-pipeline/contracts/version-derivation.md).
This document states the *rules*; those files are the *implementation*.

## 1. Versions are derived from git, never hand-assigned

A build's version is computed from git history alone — there is no field a human
edits to pick a number (FR-008, FR-010). The derivation is:

```
git describe --tags --match 'v[0-9]*' --long --dirty
```

| Source state | `semver` | `derivation` | `is_prerelease` |
|--------------|----------|--------------|-----------------|
| Commit is exactly tag `v1.2.3` | `1.2.3` | `exact-tag` | false |
| 5 commits past `v1.2.3` | `1.2.3-5-g<sha>` | `git-describe` | true |
| No tags yet | `0.0.0-<n>-g<sha>` | `git-describe` | true |
| Working tree dirty | build **fails** — never published | — | — |

The only override is `--version <tag>`, and it must name a **tag that already
exists** (R4): it pins identity to an anchored point in history, it does not let
anyone invent a number. A non-existent or non-SemVer override is rejected.

## 2. Semantic Versioning

Versions are [SemVer 2.0.0](https://semver.org): `MAJOR.MINOR.PATCH`.

- **MAJOR** — incompatible, breaking changes to a published interface.
- **MINOR** — backward-compatible new behavior.
- **PATCH** — backward-compatible fixes.

A version is created by tagging a commit `vMAJOR.MINOR.PATCH`. Releases are cut
only from an `exact-tag` state — a `git-describe` or `-dirty` version must never
be published as a release (R1; enforced by the release workflow, T035).

## 3. Pre-1.0 (`0.x`) disclosure is mandatory

While an application's MAJOR version is `0`, its interface is unstable: a
breaking change may ship in any release without a MAJOR bump. This MUST be
disclosed, not left implicit (FR-011, R3).

`derive-version` sets `pre_1_0 = true` whenever `MAJOR == 0` and emits the
compatibility disclaimer as both a `DERIVE_VERSION_DISCLAIMER:` line and a
`disclaimer` output. Every surface that reports a `0.x` version — the release
notes (T035) and the application's own version report — MUST carry that
disclaimer.

A clean `0.x` tag is still a real, releasable release (`is_prerelease = false`);
the `0.x` instability signal is carried by `pre_1_0`, distinct from the
`is_prerelease` flag that marks untagged-commit and `-rc` builds.

## 4. Every build reports the version it carries

The derived `semver` and `commit_sha` are embedded into the artifact at build
time and MUST be reportable by the running application (R2, SC-002). How is the
ecosystem adapter's choice — see each adapter's `version-embed` hook:

- Go — [`adapters/go/adapter.yml`](../adapters/go/adapter.yml)
  (`-ldflags -X main.version=… -X main.commit=…`).
- Node — [`adapters/node/adapter.yml`](../adapters/node/adapter.yml)
  (a generated `version.ts` the app imports).

The presence of a version report is mandatory; the surface (`--version`, an
endpoint, a build-info file) is not prescribed.

## 5. This policy is versioned

Like the gate policy, this document's rules are pinned by consumers via the
policy version in [`VERSION`](./VERSION). Changing a rule here is a policy
change, surfaced to every repo through the normal drift signal (FR-018).
