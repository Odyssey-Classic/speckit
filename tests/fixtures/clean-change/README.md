# Gate fixture: `clean-change`

**Intended gate outcome**: MERGEABLE. Driving category: none — every
required category (`tests`, `quality`, `security`, `docs`) passes.

This fixture is the control/happy-path case: a minimal, dependency-free
project where every hook genuinely passes. It proves US1.3 ("Clean +
approving review -> Mergeable") and, alongside the other three fixtures,
that the gate is not fail-open by accident — a fixture only passes here
because nothing about it is wrong, not because a check was skipped.

Two language variants exercise the same scenario under different
ecosystem adapters (US1.4, "same categories in a Go and a non-Go repo"):

| Variant | Adapter | Categories |
|---|---|---|
| [`go/`](./go/) | `go` | `go test` passes; `gofmt`/`go vet` clean; no dependency so `govulncheck` finds nothing; non-empty `README.md`. |
| [`node/`](./node/) | `node` | `npm test` (`node --test`) passes; `eslint`/`prettier` clean; no dependency so `npm audit` finds nothing; non-empty `README.md`. |

Exercised by `tests/e2e/gate-e2e.yml` (T015) — see that file's header for
what is asserted statically (this fixture's own tooling, offline) versus
only on a real GitHub Actions run (the actual gate verdict).
