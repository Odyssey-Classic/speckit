# clean-change — Go variant

Minimal Go module for the `clean-change` gate fixture. `main_test.go`
asserts the true result (`Add(2, 2) == 4`), so every category passes:
`go test` (tests), `gofmt`/`go vet` (quality), `govulncheck`/`gitleaks`
with no declared dependency (security), and this file (docs). See
`../README.md` for the full intent.
