# Gate fixture: `failing-test`

**Intended gate outcome**: BLOCKED. Driving category: **`tests`**.

This fixture is a minimal, otherwise-clean project whose test suite
contains one deliberately wrong assertion. Every other required category
(`quality`, `security`, `docs`) passes cleanly, so the `tests` category is
the sole reason the gate blocks — isolating US1.1 ("Breaks a test ->
Blocked; `tests` check fails with which test").

Two language variants exercise the same scenario under different
ecosystem adapters (US1.4, "same categories in a Go and a non-Go repo"):

| Variant | Adapter | `test` hook | Failing assertion |
|---|---|---|---|
| [`go/`](./go/) | `go` | `go test ./... -race -cover` | `main_test.go`'s `TestAdd` expects `Add(2, 2) == 5` (it is 4). |
| [`node/`](./node/) | `node` | `npm ci && npm test` (`node --test`) | `index.test.js` expects `add(2, 2) === 5` (it is 4). |

Both variants' `lint`/`security`/`docs` hooks pass unmodified (no
dependency is declared, so there is nothing for `govulncheck`/`npm audit`
to flag; `gofmt`/`go vet`/`eslint`/`prettier` are all clean; each variant
carries a non-empty `README.md`).

Exercised by `tests/e2e/gate-e2e.yml` (T015) — see that file's header for
what is asserted statically (this fixture's own tooling, offline) versus
only on a real GitHub Actions run (the actual gate verdict).
