# Gate fixture: `preexisting-vuln-only`

**Intended gate outcome**: SURFACED, not blocked (overall: mergeable).
Driving category: **`security`** (a finding is present, but it is
classified pre-existing — `security.threshold.preexisting: surface`,
FR-004/research.md D12).

This fixture's project (`go/`, `node/`) is **byte-for-byte the same
dependency-bearing source** as `../known-vuln-dep/` — the same real,
independently-verified vulnerable dependency
(`golang.org/x/text@v0.3.5` / `lodash@4.17.15`; see that fixture's
README for the exact verified findings). What differs is the **baseline**
in `findings/`: here, the target branch (`main`) is modeled as *already*
carrying the identical finding — i.e. this PR did not introduce the
vulnerability, it was already present before this change. Contrast with
`../known-vuln-dep/findings/`, whose baseline is empty (this PR
introduces the finding there).

Per FR-004/D12 ("don't punish a contributor for a vulnerability they
didn't introduce, while still preventing new risk"), `security-baseline.sh`
(T018) classifies a finding whose fingerprint already appears in the
baseline as `preexisting`, and that classification `surface`s the finding
(reported) rather than blocking on it. With `tests`/`quality`/`docs` all
passing cleanly (same as `known-vuln-dep`'s source), the overall gate
outcome here is **mergeable** — this is the Edge Case in the spec ("a
pre-existing vuln only -> Surfaced, not blocked") and Scenario B's third
row in `quickstart.md`.

See `../known-vuln-dep/README.md` for why this fixture ships synthetic
`findings/` files (the real scanner-to-baseline CI wiring is T050's
still-open gap) rather than relying on `gate.yml`'s current fallback (raw
hook exit code, which cannot yet tell new from pre-existing).

Exercised by `tests/e2e/gate-e2e.yml` (T015) — see that file's header for
the full static-vs-CI-only breakdown.
