# known-vuln-dep — Go variant

Minimal Go module depending on `golang.org/x/text@v0.3.5` and calling
`language.ParseAcceptLanguage` — a real, reachable call site `govulncheck
./...` flags as `GO-2022-1059` and `GO-2021-0113` (verified locally; exit
3). `go test` (tests), `gofmt`/`go vet` (quality), and this file (docs)
all pass unmodified; only `security` is affected — see `../README.md` for
how this fixture's outcome is actually asserted (`../findings/`).
