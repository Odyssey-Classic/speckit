# failing-test — Go variant

Minimal Go module for the `failing-test` gate fixture. `main_test.go`
asserts `Add(2, 2) == 5` (wrong on purpose) so `go test ./... -race
-cover` fails and the `tests` gate category blocks. `gofmt`/`go vet`
(quality), `govulncheck`/`gitleaks` (security — no dependency declared,
so nothing to flag), and this file (docs) all pass. See `../README.md`
for the full intent.
